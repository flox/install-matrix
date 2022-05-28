{pkgs ? import <nixpkgs>{}, mkTestScript ? pkgs.callPackage ./test-script.nix }:
let
  simple_install = {
    install-default = ''
      #!/bin/sh
      echo install default
    '';
    install-sleep = ''
      #!/bin/sh
      echo install
      sleep 5
    '';
  };

  testScripts = let
    verify_installed_common = ''
      # TODO finish these criteria and make sure they're all tested
      # installed means:
      #   scriptlets ensure:
      #   - the installer closure is in the /nix/store and added to the nix database
      #   - systemd units are enabled and nix-daemon.socket is started
      #   - there is a zero length file at /usr/share/nix/nix.tar.xz
      #   - users and groups are added
      #   - selinux policy is loaded
      #   - TODO verify this: channels are set up
      #   - TODO anything else in the tarball from /nix?
      #   the package manager tracks all of the following files:
      #   - there is a gcroot for each derivation used to create the closure in FLOX_GCROOT, and there are no additional gcroots in FLOX_GCROOT
      #   - binaries are linked in /usr/bin and /usr/sbin
      #   - man pages are linked in /usr/share
      #   - files from the rootfs directory
      #   - systemd unit files
      #   - various other files: flox.toml, repo files, nix-daemon.conf, flox-version
      #
      # State machine:
      # uninstalled -install_1-> installed_1
      # installed_1 -uninstall_1-> uninstalled
      #             -upgrade-> installed_2
      # TODO add transitions for installed_2
      # if we run install, uninstall, install, upgrade, and uninstall we'll hit a good chunk of this

      systemctl status nix-daemon.socket
      # nix-daemon.service must be started by the socket otherwise permissions won't be correct
      systemctl status nix-daemon.service && exit 1
      sudo nix-collect-garbage -d
      # uncomment after this doesn't run through interactive flox setup
      #[[ $(flox --version) =~ "Version: "[0-9]\.[0-9]\.[0-9] ]]
      man flox > /dev/null
      # nix can do something non-trivial. This is kinda slow because it pulls nixpkgs...
      [[ $(nix run nixpkgs#hello) == "Hello, world!" ]]
      man nix > /dev/null
      systemctl status nix-daemon.socket
      systemctl status nix-daemon.service
      test -f /etc/systemd/system/sockets.target.wants/nix-daemon.socket
      test -f /etc/systemd/system/multi-user.target.wants/nix-daemon.service
    '';
    verify_installed_fedora = ''
      ${verify_installed_common}
      sudo semodule --list | grep nix > /dev/null
      dnf search flox --repo flox | grep "Exactly Matched"
      sudo dnf update flox --repo flox
    '';
    verify_installed_ubuntu = ''
      ${verify_installed_common}
      sudo apt-get update -o Dir::Etc::sourcelist="/etc/apt/sources.list.d/flox.list" -o Dir::Etc::sourceparts="-"
    '';
    verify_uninstalled = ''
      # uninstalled means (for now focus on things scriptlets do, since they're more likely to have mistakes):
      #   - /nix does not exist
      #   - systemd units are disabled
      test -d /nix && exit 1
      systemctl status nix-daemon.socket && exit 1
      systemctl status nix-daemon.service && exit 1
      test -f /etc/systemd/system/sockets.target.wants/nix-daemon.socket && exit 1
      test -f /etc/systemd/system/multi-user.target.wants/nix-daemon.service && exit 1
      grep nixbld /etc/passwd && exit 1
      getent group nixbld && exit 1
      test -f /usr/bin/nix && exit 1
    '';
    verify_uninstalled_fedora = ''
      ${verify_uninstalled}
      sudo semodule --list | grep nix && exit 1
      dnf repolist --repo flox && exit 1
    '';
  in {
    test-rpm = ''
      set -euxo pipefail
      ${verify_installed_fedora}
      floxPath1=$(readlink /usr/bin/flox)
      sudo rpm --erase flox
      ${verify_uninstalled_fedora}
      sudo rpm -i flox.rpm
      ${verify_installed_fedora}
      sudo rpm -U flox2.rpm
      [[ $floxPath1 != $(readlink /usr/bin/flox) ]]
      ${verify_installed_fedora}
      sudo rpm --erase flox
      ${verify_uninstalled_fedora}
      exit 0
    '';
    test-deb = ''
      set -euxo pipefail
      ${verify_installed_ubuntu}
      floxPath1=$(readlink /usr/bin/flox)
      sudo dpkg --purge flox
      ${verify_uninstalled}
      sudo dpkg --install flox.deb
      ${verify_installed_ubuntu}
      sudo dpkg --install flox2.deb
      [[ $floxPath1 != $(readlink /usr/bin/flox) ]]
      ${verify_installed_ubuntu}
      sudo dpkg --purge flox
      ${verify_uninstalled}
      exit 0
    '';
  };

  loginMethods = {
    login = "bash --login";
    login-interactive = "bash --login -i";
    interactive = "bash -i";
    ssh = ""; # all of the above do SSH and then spawn appropriate shell
  };

  filters = {
    installFilter = null;
    imageFilter = null;
    loginFilter = "login";
    testFilter = "test-rpm";
  };

  "alpine-default" = {
    #image = "generic/alpine314";
    preInstall = ''
      set -xe
      sudo apk add curl xz findmnt
    '';
    install = simple_install;
    preLoad = [ { src = ./README.md; dst = "README.md";} ];
    system = "x86_64-linux";
  };
  preLoad = [ { src = ./README.md; dst = "README.md";} ];

  matrix = builtins.mapAttrs (_: v: { inherit loginMethods testScripts preLoad; } // v)
  {
  # "macos-sierra" = {
  #   # Sketchy :)
  #   image = "jhcook/macos-sierra";
  #   preInstall = "";
  #   system = "x86_64-darwin";
  # };

  # "macos-highsierra" = {
  #   # Sketchy :)
  #   image = "monsenso/macos-10.13";
  #   preInstall = "";
  #   system = "x86_64-darwin";
  # };

  "arch" = {
    image = "generic/arch";
    preInstall = ''
      pacman -S --noconfirm rsync
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "alpine-3-14" = alpine-default // {
    image = "generic/alpine314";
  };
  "alpine-3-13" = alpine-default // {
    image = "generic/alpine313";
  };
  "alpine-3-12" = alpine-default // {
    image = "generic/alpine312";
  };

  "fedora-35" = {
    image = "generic/fedora35";
    preInstall = "";
    install = {
      default = ''
        #!/bin/sh
        # sudo dnf -y --nogpgcheck --cacheonly localinstall flox.rpm
        sudo rpm -i flox.rpm
      '';
    };
    preLoad = [ { src = ./flox.rpm; dst = "flox.rpm";} { src = ./flox2.rpm; dst = "flox2.rpm";}];
    system = "x86_64-linux";
  };

  "ubuntu-21.10" = {
    image = "generic/ubuntu2110";
    box_version = "3.6.14";
    preInstall = "";
    install = {
      default = ''
        #!/bin/sh
        sudo dpkg -i flox.deb
      '';
    };
    preLoad = [ { src = ./flox.deb; dst = "flox.deb";} { src = ./flox2.deb; dst = "flox2.deb";}];
    system = "x86_64-linux";
  };

  "fedora-28" = {
    image = "generic/fedora28";
    preInstall = ''
      yum install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "fedora-27" = {
    image = "generic/fedora27";
    preInstall = ''
      yum install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "fedora-26" = {
    image = "generic/fedora26";
    preInstall = ''
      yum install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "fedora-25" = {
    image = "generic/fedora25";
    preInstall = ''
      yum install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "gentoo" = {
    image = "generic/gentoo";
    preInstall = ''
      emerge curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "centos-7" = {
    image = "centos/7";
    preInstall = ''
      yum --assumeyes install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "centos-6" = {
    image = "centos/6";
    preInstall = ''
      yum --assumeyes install curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "debian-9" = {
    image = "debian/stretch64";
    preInstall = ''
      apt-get update
      apt-get install -y curl mount
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "debian-8" = {
    image = "debian/jessie64";
    preInstall = ''
      apt-get update
      apt-get install -y curl mount
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "ubuntu-18-10-proxy" = {
    image = "generic/ubuntu1810";
    hostReqs = {
      httpProxy = true;
    };
    preInstall = ''
      apt-get update
      apt-get install -y curl
      iptables -A OUTPUT -p tcp --dport 80 -j DROP
      iptables -A OUTPUT -p tcp --dport 443 -j DROP
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "ubuntu-18-10" = {
    image = "generic/ubuntu1810";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "ubuntu-18-04" = {
    image = "generic/ubuntu1804";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };

  "ubuntu-16-04" = {
    image = "generic/ubuntu1604";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    install = simple_install;
    system = "x86_64-linux";
  };
};
in mkTestScript {
    inherit pkgs filters matrix;
  }
