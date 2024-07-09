{
  description = "Nix Flake for Keymapp app from ZSA";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    keymapp = {
      url = "file+https://oryx.nyc3.cdn.digitaloceanspaces.com/keymapp/keymapp-1.2.1.tar.gz";
      flake = false;
    };
  };

  outputs =
    { nixpkgs
    , self
    , systems
    , pre-commit-hooks
    , treefmt-nix
    , ...
    } @ inputs:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f
        (import nixpkgs { inherit system; })
      );
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs (_: {
        projectRootFile = "flake.nix";
        programs = {
          deadnix.enable = true;
          nixpkgs-fmt.enable = true;
          statix.enable = true;
        };
      }));
    in
    {
      packages = eachSystem (pkgs:
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
              libsoup_3
              libusb1
              systemd
              webkitgtk_4_1
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
          inherit keymapp keymapp-build;
          default = keymapp;
        });

      overlays.default = final: _prev: {
        inherit (self.packages.${final.system}) keymapp keymapp-build;
      };

      apps = eachSystem (pkgs: rec {
        keymapp = {
          type = "app";
          program = "${pkgs.keymapp}/bin/keymapp";
        };
        default = keymapp;
      });

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          inherit (self.checks.${pkgs.system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${pkgs.system}.pre-commit-check.enabledPackages;
          packages = [
            treefmtEval.${pkgs.system}.config.build.wrapper
          ];
        };
      });

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        pre-commit-check = pre-commit-hooks.lib.${pkgs.system}.run {
          src = ./.;
          hooks.treefmt = {
            enable = true;
            package = treefmtEval.${pkgs.system}.config.build.wrapper;
          };
        };
      });
    };
}
