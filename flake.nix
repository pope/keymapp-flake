{
  description = "Nix Flake for Keymapp app from ZSA";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keymapp = {
      url = "file+https://oryx.nyc3.cdn.digitaloceanspaces.com/keymapp/keymapp-1.0.7.tar.gz";
      flake = false;
    };
  };

  outputs =
    { flake-parts
    , devenv
    , treefmt-nix
    , ...
    } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devenv.flakeModule
        flake-parts.flakeModules.easyOverlay
        treefmt-nix.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      perSystem = { config, pkgs, ... }:
        let
          keymapp-build = pkgs.stdenv.mkDerivation {
            name = "keymapp-build";
            src = inputs.keymapp;
            dontUnpack = false;
            dontConfigure = true;
            dontBuild = true;
            unpackPhase = ''
              runHook preUnpack

              mkdir keymapp
              tar xzf "$src"

              runHook postUnpack
            '';
            installPhase = ''
              runHook preInstall

              mkdir -p "$out"
              cp keymapp "$out"
              cp icon.png "$out"

              runHook postInstall
            '';
            meta = with pkgs.lib; {
              homepage = "https://blog.zsa.io/keymapp/";
              # TODO(pope): Figure out how to import and accept unfree code. Then re-enable.
              # license = licenses.unfree;
              sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            };
          };
          keymapp = pkgs.buildFHSUserEnv {
            name = "keymapp";
            runScript = pkgs.writeShellScript "keymapp-wrapper.sh" ''
              exec ${keymapp-build}/keymapp
            '';
            targetPkgs = pkgs: with pkgs; [
              gdk-pixbuf
              glib
              gtk3
              libgudev
              libusb1
              systemd
              webkitgtk
            ];
            extraInstallCommands =
              let
                desktopItem = pkgs.makeDesktopItem {
                  name = "keymapp";
                  desktopName = "Keymapp";
                  genericName = "Keyboard Mapper";
                  exec = "keymapp";
                  type = "Application";
                  icon = "${keymapp-build}/icon.png";
                };
                udevRules = ./90-keymapp.rules;
              in
              ''
                mkdir -p $out/share/applications
                ln -s ${desktopItem}/share/applications/* $out/share/applications

                mkdir -p $out/etc/udev/rules.d
                ln -s ${udevRules} $out/etc/udev/rules.d/90-keymapp.rules
              '';
          };
        in
        {
          overlayAttrs = {
            inherit (config.packages) keymapp keymapp-build;
          };

          packages = {
            inherit keymapp keymapp-build;
            default = keymapp;
          };

          devenv.shells.default = {
            packages = [
              config.treefmt.build.wrapper
            ];
            pre-commit = {
              hooks.treefmt.enable = true;
              settings.treefmt.package = config.treefmt.build.wrapper;
            };
            difftastic.enable = true;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              deadnix.enable = true;
              nixpkgs-fmt.enable = true;
              statix.enable = true;
            };
          };
        };
    };
}
