{ lib, config, pkgs, ... }:
let
  cfg = config.hardware.raspberry-pi;
  render-raspberrypi-config = let
    render-options = opts:
      lib.strings.concatStringsSep "\n" (render-dt-kvs opts);
    render-dt-param = x: "dtparam=" + x;
    render-dt-kv = k: v:
      if isNull v.value then
        k
      else
        let vstr = toString v.value; in "${k}=${vstr}";
    render-dt-kvs = x:
      lib.attrsets.mapAttrsToList render-dt-kv
      (lib.filterAttrs (k: v: v.enable) x);
    render-dt-overlay = { overlay, args }:
      "dtoverlay=" + overlay + "\n"
      + lib.strings.concatMapStringsSep "\n" render-dt-param args + "\n"
      + "dtoverlay=";
    render-base-dt-params = params:
      lib.strings.concatMapStringsSep "\n" render-dt-param
      (render-dt-kvs params);
    render-dt-overlays = overlays:
      lib.strings.concatMapStringsSep "\n" render-dt-overlay
      (lib.attrsets.mapAttrsToList (k: v: {
        overlay = k;
        args = render-dt-kvs v.params;
      }) (lib.filterAttrs (k: v: v.enable) overlays));
    render-config-section = k:
      { options, base-dt-params, dt-overlays }:
      let
        all-config = lib.concatStringsSep "\n" (lib.filter (x: x != "") [
          (render-options options)
          (render-base-dt-params base-dt-params)
          (render-dt-overlays dt-overlays)
        ]);
      in ''
        [${k}]
        ${all-config}
      '';
  in conf:
  lib.strings.concatStringsSep "\n"
  (lib.attrsets.mapAttrsToList render-config-section conf);
in {
  options = {
    hardware.raspberry-pi = {
      config = let
        rpi-config-param = {
          options = {
            enable = lib.mkEnableOption "attr";
            value =
              lib.mkOption { type = with lib.types; oneOf [ int str bool ]; };
          };
        };
        dt-param = {
          options = {
            enable = lib.mkEnableOption "attr";
            value = lib.mkOption {
              type = with lib.types; nullOr (oneOf [ int str bool ]);
              default = null;
            };
          };
        };
        dt-overlay = {
          options = {
            enable = lib.mkEnableOption "overlay";
            params = lib.mkOption {
              type = with lib.types; attrsOf (submodule dt-param);
            };
          };
        };
        raspberry-pi-config-options = {
          options = {
            options = lib.mkOption {
              type = with lib.types; attrsOf (submodule rpi-config-param);
              default = { };
              example = {
                enable_gic = {
                  enable = true;
                  value = true;
                };
                arm_boost = {
                  enable = true;
                  value = true;
                };
              };
            };
            base-dt-params = lib.mkOption {
              type = with lib.types; attrsOf (submodule rpi-config-param);
              default = { };
              example = {
                i2c = {
                  enable = true;
                  value = "on";
                };
                audio = {
                  enable = true;
                  value = "on";
                };
              };
              description = "parameters to pass to the base dtb";
            };
            dt-overlays = lib.mkOption {
              type = with lib.types; attrsOf (submodule dt-overlay);
              default = { };
              example = { vc4-kms-v3d = { cma-256 = { enable = true; }; }; };
              description = "dtb overlays to apply";
            };
          };
        };
      in lib.mkOption {
        type = with lib.types; attrsOf (submodule raspberry-pi-config-options);
      };
      config-output = lib.mkOption {
        type = lib.types.package;
        default = pkgs.writeTextFile {
          name = "config.txt";
          text = ''
            # This is a generated file. Do not edit!
            ${render-raspberrypi-config cfg.config}
          '';
        };
      };
    };
  };
}
