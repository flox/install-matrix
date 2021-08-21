{pkgs ? import <nixpkgs>{}, mkTestScript ? pkgs.callPackage ./test-script.nix }:
let
  debian_install = {
    install-default = ''
      #!/bin/sh
      set -eux
      sudo dpkg -i flox.deb
    '';
    double-install = ''
      #!/bin/sh
      set -eux
      sudo dpkg -i flox.deb &
      sudo dpkg -i flox.deb
      wait
    '';
  };

  testScripts = {
    help = ''
      #!/bin/sh
      flox --help
    '';
    version = ''
      #!/bin/sh
      flox --version
    '';
  };

  loginMethods = {
    login = "bash --login";
    login-interactive = "bash --login -i";
    interactive = "bash -i";
    ssh = ""; # all of the above do SSH and then spawn appropriate shell
  };

  filters = {
    imageFilter = "(debian|ubuntu).*";
    #installFilter = "default";
  };

  matrix = builtins.mapAttrs (_: v: { inherit loginMethods testScripts; } // v)
  {
  "macos-sierra" = {
    # Sketchy :)
    image = "jhcook/macos-sierra";
    preInstall = "";
    system = "x86_64-darwin";
  };

  "macos-highsierra" = {
    # Sketchy :)
    image = "monsenso/macos-10.13";
    preInstall = "";
    system = "x86_64-darwin";
  };

  "arch" = {
    image = "generic/arch";
    preInstall = ''
      pacman -S --noconfirm rsync
    '';
    system = "x86_64-linux";
  };

  "alpine-3-8" = {
    image = "generic/alpine38";
    preInstall = ''
      apk --no-cache add curl
    '';
    system = "x86_64-linux";
  };

  "alpine-3-7" = {
    image = "generic/alpine37";
    preInstall = ''
      apk --no-cache add curl
    '';
    system = "x86_64-linux";
  };

  "alpine-3-6" = {
    image = "generic/alpine36";
    preInstall = ''
      apk --no-cache add curl
    '';
    system = "x86_64-linux";
  };

  "alpine-3-5" = {
    image = "generic/alpine35";
    preInstall = ''
      apk --no-cache add curl
    '';
    system = "x86_64-linux";
  };

  "fedora-28" = {
    image = "generic/fedora28";
    preInstall = ''
      yum install curl
    '';
    system = "x86_64-linux";
  };

  "fedora-27" = {
    image = "generic/fedora27";
    preInstall = ''
      yum install curl
    '';
    system = "x86_64-linux";
  };

  "fedora-26" = {
    image = "generic/fedora26";
    preInstall = ''
      yum install curl
    '';
    system = "x86_64-linux";
  };

  "fedora-25" = {
    image = "generic/fedora25";
    preInstall = ''
      yum install curl
    '';
    system = "x86_64-linux";
  };

  "gentoo" = {
    image = "generic/gentoo";
    preInstall = ''
      emerge curl
    '';
    system = "x86_64-linux";
  };

  "centos-7" = {
    image = "centos/7";
    preInstall = ''
      yum --assumeyes install curl
    '';
    system = "x86_64-linux";
  };

  "centos-6" = {
    image = "centos/6";
    preInstall = ''
      yum --assumeyes install curl
    '';
    system = "x86_64-linux";
  };

  "debian-9" = {
    image = "debian/stretch64";
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    preInstall = ''
      apt-get update
      apt-get install -y curl mount
    '';
    install = debian_install;
    system = "x86_64-linux";
  };

  "debian-8" = {
    image = "debian/jessie64";
    preInstall = ''
      apt-get update
      apt-get install -y curl mount
    '';
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    install = debian_install;
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
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    install = debian_install;
    system = "x86_64-linux";
  };

  "ubuntu-18-10" = {
    image = "generic/ubuntu1810";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    install = debian_install;
    system = "x86_64-linux";
  };

  "ubuntu-18-04" = {
    image = "generic/ubuntu1804";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    install = debian_install;
    system = "x86_64-linux";
  };

  "ubuntu-16-04" = {
    image = "generic/ubuntu1604";
    preInstall = ''
      apt-get update
      apt-get install -y curl
    '';
    preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
    install = debian_install;
    system = "x86_64-linux";
  };
};
in mkTestScript {
    inherit pkgs filters matrix;
  }
