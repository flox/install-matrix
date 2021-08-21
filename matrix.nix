rec {
  # (images x install) VMs
  # (login x tests) in each VM

  installScripts = {
    install-default = ''
      #!/bin/sh
      set -eu
      sudo dpkg -i flox.deb
    '';
    install-verbose = ''
      #!/bin/sh
      set -eux
      sudo dpkg -i flox.deb
    '';
  };

  install= {
    install-default = ''
      #!/bin/sh
      set -eu
      sudo dpkg -i flox.deb
    '';
    install-verbose = ''
      #!/bin/sh
      set -eux
      sudo dpkg -i flox.deb
    '';
  };

  testScripts = {
    "test.sh" = ''
      #!/bin/sh
      flox --help
    '';
  };

  loginMethods = {
    login = "bash --login";
    login-interactive = "bash --login -i";
    interactive = "bash -i";
    ssh = ""; # all of the above do SSH and then spaw appropriate shell
  };

  images = {
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
      preInstall = ''
        apt-get update
        apt-get install -y curl mount
      '';

      install = install;
      preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
      system = "x86_64-linux";
    };

    "debian-8" = {
      image = "debian/jessie64";
      preInstall = ''
        apt-get update
        apt-get install -y curl mount
      '';
      preLoad = [ { src = "./flox.deb"; dst = "flox.deb";} ];
      system = "x86_64-linux";
    };

    "ubuntu-18-10-proxy" = {
      image = "ubuntu/cosmic64";
      hostReqs = {
        httpProxy = true;
      };
      preInstall = ''
        apt-get update
        apt-get install -y curl
        iptables -A OUTPUT -p tcp --dport 80 -j DROP
        iptables -A OUTPUT -p tcp --dport 443 -j DROP
      '';
      preLoad = [ { src = ./flox-bad.deb; dst = "flox.deb";} ];
      system = "x86_64-linux";
    };

    "ubuntu-18-10" = {
      image = "ubuntu/cosmic64";
      preInstall = ''
        apt-get update
        apt-get install -y curl
      '';
      system = "x86_64-linux";
    };

    "ubuntu-18-04" = {
      image = "ubuntu/bionic64";
      preInstall = ''
        apt-get update
        apt-get install -y curl
      '';
      system = "x86_64-linux";
    };

    "ubuntu-16-04" = {
      image = "ubuntu/xenial64";
      preInstall = ''
        apt-get update
        apt-get install -y curl
      '';
      system = "x86_64-linux";
    };

    "ubuntu-14-04" = {
      image = "ubuntu/trusty64";
      preInstall = ''
        apt-get update
        apt-get install -y curl
      '';
      system = "x86_64-linux";
    };

    "ubuntu-12-04" = {
      image = "ubuntu/precise64";
      preInstall = ''
        apt-get update
        apt-get install -y curl
      '';
      system = "x86_64-linux";
    };
  };
}
