# keymapp-flake

A Nix Flake for the Keymapp app on an `x86_64-linux` system.

**NOTE**: This is not Open Source software. ZSA distributes a binary build and
the whole point of this flake is to make it workable on NixOS.

This flake makes the `keymapp` app runnable under NixOS, provides the udev
rules to connect to the Voyager hardware, and creates a desktop entry.

## Setup

Import this flake into your own and add the overlays to your config.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    keymapp = {
      url = "github:pope/keymapp-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, keymapp }:
    {
      nixosConfigurations."host" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux;"
        modules = [
          { nixpkgs.overlays = [ keymapp.overlays.default ]; }
          ./configuration.nix
        ];
      };
    };
}
```

Next, enable the udev rules and set up your user account to be part of the
`plugdev` user group.

```nix
# This would be in your configuration.nix for example.
{ pkgs, ... }:

{
  users = {
    # Replace `you` with your username.
    users.you.extraGroups = [ "plugdev" ];
    groups.plugdev = { };
  };

  services.udev.packages = [ pkgs.keymapp ];
}
```

Lastly, install keymapp.

```nix
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.keymapp ];

  # or for just your user (don't forget to replace `you`)
  users.users.you.packages = [ pkgs.keymapp ];
}
```
