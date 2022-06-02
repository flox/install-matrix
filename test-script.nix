{ pkgs ? import <nixpkgs>{},
matrix ? null,
filters ? null,
}:
let
  config = {
    installFilter = null;
    imageFilter = null;
    loginFilter = null;
    testFilter = null;
  } // filters;

  lib = import ./lib.nix {
    inherit pkgs matrix;
    inherit (config) installFilter imageFilter loginFilter testFilter;
  };

  inherit (config) testFilter loginFilter;
  inherit (lib) shellcheckedScript filter casesToRun;

  testScript = testScripts: shellcheckedScript "test.sh"
    (let
      filteredTests = filter testFilter testScripts;
    in
    ''
#!/usr/bin/env bash
export PS4=' ''${BASH_SOURCE}::''${FUNCNAME[0]}::$LINENO '
set -u
set -o pipefail

runtest() {
    testFn=$1

    local testdir="$TESTDIR/tests/$testFn"
    mkdir -p "$testdir"

    start=$(date '+%s')
    echo "Starting: $testFn"
    echo "PATH: $PATH"
    (
        set -e
        "$testFn"
    ) 2>&1 | tee "$testdir/log" | sed 's/^/    /'
    exitcode=$?
    end=$(date '+%s')
    duration=$((end - start))
    echo "$exitcode" > "$testdir/exitcode"
    echo "$duration" > "$testdir/duration"

    echo "Finishing: $testFn, duration:$duration result:$exitcode"
}

main() {
    readonly TESTDIR=./nix-test-matrix-log
    rm -rf "$TESTDIR"
    mkdir "$TESTDIR"

    (
        for i in "$@" ; do
            runtest "$i"
        done
    )

    tar -cf ./nix-test-matrix-log.tar "$TESTDIR"
}
${pkgs.lib.concatStringsSep "\n"
(pkgs.lib.mapAttrsToList (name: value:
"${name}(){
  ${value}
}
    ") filteredTests
  )}
main ${pkgs.lib.concatStringsSep " " (builtins.attrNames filteredTests)}
'');

  mkVagrantfile = name: details: pkgs.writeText "Vagrantfile" ''
    Vagrant.configure("2") do |config|
      config.vm.box = "${details.image}"
      ${pkgs.lib.concatStringsSep "\n" (map (item: "
      config.vm.provision \"file\", source: \"${item.dst}\", destination: \"${item.dst}\"
      ") details.preLoad)}
      config.vm.provision "shell", inline: <<-SHELL
        set +x
        ${details.preInstall}
      SHELL
      config.vm.synced_folder ".", "/vagrant", disabled: true
      config.vm.box_check_update = false
      config.vm.provider "virtualbox" do |vb|
        vb.gui = false
        vb.memory = "2048"

        # for macos:
        vb.customize ["modifyvm", :id, "--usb", "off"]
        vb.customize ["modifyvm", :id, "--usbehci", "off"]
      end
    end
  '';

  mkTestScript = installScript: name: imageConfig: shellcheckedScript "run-${installScript.name}-${name}.sh" ''
    #!/usr/bin/env bash
    set -eu

    PATH=${pkgs.vagrant}/bin/:${pkgs.coreutils}/bin/:$PATH

    destdir="$1"
    shift

    scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
    finish() {
      rm -rf "$scratch"
    }
    trap finish EXIT

    # TODO: use rsync to support folder structures not just individual files
    ${pkgs.lib.concatStringsSep "\n"
      (builtins.map (load: "cp ${load.src} \"$scratch/${load.dst}\"")
      imageConfig.preLoad
    )}

    cd "$scratch"

    finish() {
      vagrant destroy --force
      rm -rf "$scratch"
    }
    trap finish EXIT

    mkdir log-results

    cp ${mkVagrantfile name imageConfig} ./Vagrantfile
    cp ./Vagrantfile ./log-results/

    echo "${name}" > ./log-results/image-name
    echo "${installScript.name}" > ./log-results/install-method

    (
      vagrant up --provider=libvirt

      vagrant ssh -- tee install < ${shellcheckedScript installScript.name installScript.script} >/dev/null
      vagrant ssh -- chmod +x install

      vagrant ssh -- tee testscript < ${testScript imageConfig.testScripts } >/dev/null
      vagrant ssh -- chmod +x testscript

      ${if (imageConfig.hostReqs or {}).httpProxy or false then ''
        gw=$(vagrant ssh -- ip route get 4.2.2.2 \
              | head -n1 | cut -d' ' -f3)
        printf "\n\nhttp_proxy=%s:%d\nhttps_proxy=%s:%d\n" \
          "$gw" "3128" "$gw" "3128" \
          | vagrant ssh -- sudo tee -a /etc/environment
      '' else ''
      '' }

      vagrant ssh -- ./install 2>&1 \
        | tee ./install-log | sed -e "s/^/${name}-install    /"
      installexitcode=''${PIPESTATUS[0]}
      echo "$installexitcode" > ./install-exitcode

      set +e

      runtest() {
        name=$1
        shift
        vagrant ssh -- "$@" ./testscript 2>&1 \
          | sed -e "s/^/${name}-test-$name    /"
        mkdir -p "./log-results/test-results/$name"
        vagrant ssh -- cat ./nix-test-matrix-log.tar | tar -xC "./log-results/test-results/$name"
      }

      export VAGRANT_PREFER_SYSTEM_BIN=1
      export -f runtest

    ${pkgs.lib.strings.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (name: value: "runtest ${name} ${value}")
      (filter loginFilter imageConfig.loginMethods) )}
    ) 2>&1 | tee ./log-results/run-log

    mv ./log-results "$destdir"
  '';

  mkImageFetchScript = imagename:
    shellcheckedScript "fetch-image-${imagename}" ''
        #!/bin/bash
        set -euo pipefail
        echo "--- Fetching ${imagename}"

        PATH=${pkgs.vagrant}/bin/:${pkgs.coreutils}/bin/:${pkgs.gnugrep}/bin/:${pkgs.curl}/bin/:$PATH

        if ! vagrant box list | grep -q "${imagename}"; then
          vagrant box add "${imagename}" --provider=libvirt
        fi
      '';
in shellcheckedScript "run-tests.sh"
''
  #!/bin/sh
  set -eu

  PATH="${pkgs.coreutils}/bin/:${pkgs.findutils}/bin/$PATH"

  destdir=$(realpath "$1")
  mkdir -p "$destdir"

  set +eu

  echo "Pre-fetching images"
  cat <<EOF | grep "$2" | xargs -L 1 -P 2 bash
  ${pkgs.lib.concatStringsSep "\n"
  (pkgs.lib.lists.unique (builtins.map (image: mkImageFetchScript image.config.image)
    casesToRun
    ))}
  EOF

  echo "Running tests"
  cat <<EOF | grep "$2" | grep "$3" | xargs -L 1 -P 1 bash
  ${pkgs.lib.concatStringsSep "\n"
  (builtins.map (case:
    let cmd = mkTestScript case.config.install case.name case.config;
    in "${cmd} \"$destdir/${case.config.install.name}-${case.name}\"") casesToRun
    )}
  EOF
''
