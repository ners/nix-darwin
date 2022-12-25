{ pkgs, lib, config, ... }:

let
  cfg = config.nix.monitored;
  inherit (lib) mkOption types mdDoc literalExpression;
in
{
  meta.maintainers = [ lib.maintainers.ners ];

  options.nix.monitored = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Whether to enable Nix-Monitored.
        Enabling this will replace the system Nix.
      '';
    };
    package = mkOption {
      type = types.package;
      default = pkgs.nix-monitored;
      defaultText = literalExpression "pkgs.nix-monitored";
      description = mdDoc ''
        This option specifies the Nix-Monitored package instance to use.
      '';
    };
  };

  config = lib.mkIf config.nix.monitored.enable {
    nix.package = cfg.package;
    nixpkgs.overlays = [
      (self: super: {
        nix-direnv = super.nix-direnv.override {
          nix = cfg.package;
        };
      })
    ];
  };
}
