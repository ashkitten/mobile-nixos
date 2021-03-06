{ config, lib, pkgs, ... }:

with lib;

{
  options.mobile.adbd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enables adbd on the device.
      '';
    };
  };

  config = lib.mkIf config.mobile.adbd.enable {
    assertions = [
      { assertion = config.mobile.system.type == "android";
        message = "adb is only available on Android";
      }
      { assertion = config.mobile.boot.stage-1.usb.enable;
        message = "adb requires mobile.boot.stage-1.usb.enable = true";
      }
    ];

    mobile.boot.stage-1 = {
      usb.features = [ "adb" ];

      tasks = [
        (pkgs.writeText "adbd-task.rb" ''
          class Tasks::ADBD < SingletonTask
            def initialize()
              add_dependency(:Mount, "/dev/usb-ffs/adb")
              Targets[:SwitchRoot].add_dependency(:Task, self)
            end
            
            def run()
              System.spawn("adbd")
            end
          end
        '')
      ];

      extraUtils = with pkgs; [{
        package = adbd;
        extraCommand = ''cp -fpv "${glibc.out}"/lib/libnss_files.so.* "$out"/lib/'';
      }];
    };

    boot.specialFileSystems = {
      # This is required for gadgetfs configuration.
      "/dev/usb-ffs/adb" = {
        device = "adb";
        fsType = "functionfs";
        options = [ "nosuid" "noexec" "nodev" ];
      };
    };

    boot.postBootCommands = ''
      # Restart adbd early during stage-2
      ${pkgs.procps}/bin/pkill -x adbd
      ${pkgs.adbd}/bin/adbd &
    '';
  };
}
