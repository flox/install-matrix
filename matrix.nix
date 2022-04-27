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

  testScripts = {
    upgrade = ''
      #!/bin/sh
      set -euxo pipefail
      verify_install() {
        sudo systemctl status nix-daemon
        sudo nix-collect-garbage -d
        readlink /usr/bin/nix
        nix profile list
      }
      verify_install
      sudo dnf -y --nogpgcheck --cacheonly localinstall flox2.rpm
      verify_install
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
    imageFilter = "fedora-35";
    loginFilter = "login";
    testFilter = null;
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
        sudo dnf -y --nogpgcheck --cacheonly localinstall flox.rpm
      '';
    };
    preLoad = [ { src = ./flox.rpm; dst = "flox.rpm";} { src = ./flox2.rpm; dst = "flox2.rpm";}];
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
