# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

/*let
  # 1) Import nixpkgs-unstable so we have replaceVars
  system = builtins.currentSystem;
  unstable = import (builtins.fetchTarball {
    url    = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    # sha256 = "<pin-the-unstable-commit>";
  }) { inherit system; };

  # 2) Fetch agenix source once
  agenixSrc = builtins.fetchTarball {
    url    = "https://github.com/ryantm/agenix/archive/main.tar.gz";
    # sha256 = "<pin-the-agenix-commit>";
  };
in
{
  # 3) Overlay your stable pkgs with the agenix package built by unstable
  nixpkgs.overlays = [
    (final: prev: {
      agenix = unstable.callPackage "${agenixSrc}/pkgs/agenix.nix" {
        # Pass in the helper that agenix.nix expects:
        replaceVars = unstable.replaceVars;
      };
    })
  ];
*/

let
  lock-idle = pkgs.writeShellScriptBin "lock-idle" ''
    #!/usr/bin/env sh
    # kein set -e, damit wir Logs bekommen auch wenn ein Schritt fehlschlägt
    set -u

    BR=${pkgs.brightnessctl}/bin/brightnessctl
    BL=${pkgs.betterlockscreen}/bin/betterlockscreen
    XH=${pkgs.xidlehook}/bin/xidlehook

    # Log & State
    if printenv XDG_RUNTIME_DIR >/dev/null 2>&1 && [ -n "$XDG_RUNTIME_DIR" ]; then
      LOG="$XDG_RUNTIME_DIR/lock-idle.log"
      STATE="$XDG_RUNTIME_DIR/.orig-br"
    else
      UID="$(id -u)"
      LOG="/run/user/$UID/lock-idle.log"
      STATE="/run/user/$UID/.orig-br"
    fi
    log() { printf '%s %s\n' "$(date +%F_%T)" "$*" >>"$LOG"; }

    save_once() {
      [ -f "$STATE" ] || { "$BR" g > "$STATE" 2>>"$LOG"; log "saved raw=$(cat "$STATE")"; }
    }
    restore_if_saved() {
      if [ -f "$STATE" ]; then
        RAW="$(cat "$STATE" 2>/dev/null || true)"
        [ -n "${RAW:-}" ] && { "$BR" set "$RAW" >>"$LOG" 2>&1 || true; log "restored raw=$RAW"; }
        rm -f "$STATE" || true
      else
        log "no state to restore"
      fi
    }

    arg="run"; [ "$#" -ge 1 ] && arg="$1"

    case "$arg" in
      dim)
        log "dim"
        save_once
        "$BR" set 10% >>"$LOG" 2>&1 || true
        ;;
      undim)
        log "undim"
        restore_if_saved
        ;;
      lock)
        log "lock"
        save_once
        "$BR" set 10% >>"$LOG" 2>&1 || true
        "$BL" -l -- -n >>"$LOG" 2>&1 || true
        restore_if_saved
        ;;
      run|*)
        log "start xidlehook"
        exec "$XH" --detect-sleep \
          --timer 360 "$0 dim" "$0 undim" \
          --timer 420 "$0 lock" :
        ;;
    esac
  '';


in
  {
 imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
      <home-manager/nixos>
# "${agenixSrc}/modules/age.nix"
     ];
/*  age.identityPaths = [
    "/home/tom/.ssh/id_ed25519_nixos"  # Dein gerade erstellter ed25519-Key
    # optional weitere, z.B. root:
    # "/root/.ssh/id_ed25519"
  ];
  age.secrets."stripe-api-key" = {
    file  = /etc/nixos/secrets/stripe-api-key.age;
    owner = "tom";
    group = "root";
    mode  = "600";
  };
*/

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.grub.device = "/dev/sda";
  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  #  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.firewall.allowedUDPPorts = [ 1194 ]; # OpenVPN Standardport
  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  networking.enableIPv6 = false;
  boot.kernelParams = [ "ipv6.disable=1" ];  # zusätzlich, greift nach Reboot


  #docker aktivieren
  virtualisation.docker.enable = true;

  services.fwupd.enable = true;

#  networking = {
#    wireless = {
#      enable = true;
#      networks = {
#        "FRITZ!Box 7530 KH" = {
#          psk = "";
#        };
#      };
#    };
#  };
  
   
#  nix.gc = {
#    automatic = true;
#    dates = "hourly";
#    options = "--delete-older-than 60d";
#  };



  services.redshift.enable = true;
  location = {
    provider = "manual";
    latitude = 52.52;   # z.B. Berlin
    longitude = 13.405;
  };
  services.redshift.temperature = { day = 5500; night = 3700; };



systemd.user.services.lock-idle = {
  description = "xidlehook + brightness restore";
  after = [ "graphical-session.target" ];
  partOf = [ "graphical-session.target" ];
  wantedBy = [ "default.target" ];
  serviceConfig = {
    ExecStart = "${lock-idle}/bin/lock-idle";
    Restart = "always";
    # Optional:
    # RestartSec = 2;

  };
};

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "12:00" ]; # Optional; allows customizing optimisation schedule
    
  nixpkgs.config.allowUnfree = true;
 
  services.pcscd.enable = true; 

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  #  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  system.activationScripts = {
    startScript = {
      text = ''
${pkgs.coreutils}/bin/mkdir -p /home/tom/Pictures/screenshots

if [ ! -d "/home/tom/setup" ]; then
    ${pkgs.git}/bin/git clone https://github.com/tombo09/setup.git /home/tom/setup
fi

if [ ! -d "/home/tom/setup" ]; then
  ${pkgs.coreutils}/bin/cp -r /setup /home/tom/
fi

if [ ! -L "/home/tom/.config/background.jpg" ]; then
  ${pkgs.coreutils}/bin/ln -s /home/tom/setup/background.jpg /home/tom/.config/background.jpg
fi

${pkgs.coreutils}/bin/chown -R tom:users /home/tom
${pkgs.coreutils}/bin/chown root:root /home/tom/setup/configuration.nix
${pkgs.coreutils}/bin/chmod 644 /home/tom/setup/configuration.nix

      '';
    deps = [];
    };
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.windowManager.i3.enable = true;



  services.xserver = {

  xkb.layout = "myus";    # dein Name aus extraLayouts
  xkb.variant = "";       # leer lassen, wenn du "basic" willst
    # Custom-Layout einbinden
    xkb.extraLayouts.myus = {
      description = "US + AltGr: ä ö ü ß € ¢";
      languages = [ "eng" "deu" ];
      symbolsFile = pkgs.writeText "myus" ''
        // Basis: US, Ebene 3 via Right Alt (AltGr)
        xkb_symbols "basic" {
          include "us(basic)"
          include "level3(ralt_switch)"

          // e/E -> AltGr: €
          key <AD03> { [ e, E, EuroSign, EuroSign ] };
          // c/C -> AltGr: ¢
          key <AB03> { [ c, C, cent, cent ] };

          // a/A -> AltGr: ä/Ä
          key <AC01> { [ a, A, adiaeresis, Adiaeresis ] };
          // o/O -> AltGr: ö/Ö
          key <AD09> { [ o, O, odiaeresis, Odiaeresis ] };
          // u/U -> AltGr: ü/Ü
          key <AD07> { [ u, U, udiaeresis, Udiaeresis ] };
          // s/S -> AltGr: ß/ẞ
          key <AC02> { [ s, S, ssharp, U1E9E ] };
        };
      '';
    };


  };





  services.xserver.displayManager.sessionCommands = ''
#    ${pkgs.xorg.xmodmap}/bin/xmodmap "${pkgs.writeText  "xkb-layout" ''
     
#   ! Map umlauts to RIGHT ALT + <key>
#        keycode 108 = Mode_switch
#        keysym e = e E EuroSign
#        keysym c = c C cent
#        keysym a = a A adiaeresis Adiaeresis
#        keysym o = o O odiaeresis Odiaeresis
#        keysym u = u U udiaeresis Udiaeresis
#        keysym s = s S ssharp
#      ''}"

   # DPMS and Screensaver settings
     xset +dpms
     xset dpms 0 0 600
     xset s 0 0
     xset r rate 280 45
    '';



#  systemd.user.services.setxkbmap = {
#    description = "Set X Keyboard Map";
#    serviceConfig = {
#      ExecStart = "${pkgs.xorg.setxkbmap}/bin/setxkbmap us";
#    };
#    wantedBy = [ "default.target" ];
#  };

  # Configure keymap in X11
#  services.xserver.xkb.layout = "us";
#  services.xserver.xkb.options = "eurosign:e,caps:escape";





  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;
  # OR
   services.pipewire = {
    enable = false;
  #   pulse.enable = true;
   };
 

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput = {
      enable = true;
      touchpad = {
        sendEventsMode = "enabled";
        scrollMethod = "twofinger";
        naturalScrolling = false;
        tapping = true;
        accelProfile = "flat";
        accelSpeed = "1";
      };
    };
 

  services.usbmuxd.enable = true; # for mounting iphone  


  nix.settings.experimental-features = [ "nix-command" "flakes" ];

 
  services.logind = {

	lidSwitch = "suspend-then-hibernate";
	lidSwitchDocked = "suspend-then-hibernate";
	lidSwitchExternalPower = "suspend-then-hibernate";
        powerKey = "suspend-then-hibernate";
	powerKeyLongPress = "hibernate";
	extraConfig = ''
IdleAction=suspend-then-hibernate
IdleActionSec=5s
        '';
  };

  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
    percentageLow = 10;
    percentageCritical = 5;
    percentageAction = 3;
    ignoreLid=false;
  };


  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m 
    SuspendState=mem   #suspendtoidle is buggy 
  '';
   
  services.devmon.enable = true;
  services.udisks2.enable = true;



  services.cron = {
    enable = true;
    systemCronJobs = [
     "*/2 * * * * tom check-battery.sh"
     "*/30 * * * * tom backup-home.sh"
   ];
  };


#security.pam = {
#  services.login = {
# };
#  };








  security.pam.services.login.rules.auth = {
    faillock_preauth = {
      order = 100;
      control = "required";
      modulePath = "pam_faillock.so";
      settings = {
        preauth = true;
        silent = true;
        deny = "5";
        unlock_time = "600"; # Sperre für 10 Minuten
      };
    };
    faillock_authfail = {
      order = 200;
      control = "required";
      modulePath = "pam_faillock.so";
      settings = {
        authfail = true;
        deny = "5";
        unlock_time = "600"; # Sperre für 10 Minuten
      };
    };
 };


 
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
   mutableUsers = false;
   users.tom = {
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" "docker" ]; # Enables ‘sudo’ for the user.
     hashedPassword = "$6$13/UxgqtVvIrUpnW$dd4GyMsqHhWmB26YMtlKnWDmNQecwTy2rZVwFKwVZ.7G78kX7Yg2HIOdIK3RmoJIKjCHwD8Fnr93Oj.lZswjY1";
     packages = with pkgs; [
       firefox
       tree
       vscode
       keepassxc
       kitty
       dmenu
       obsidian
       yubioath-flutter
       jetbrains.idea-ultimate
       gnupg
       spotify
       anki
     ];
  };
};


  fonts.packages = with pkgs; [
    font-awesome
  ];
    
 
  services.udev.packages = with pkgs; [
    sudo
  ];


  services.udev.extraRules = let
    unlockAndMount = pkgs.writeShellApplication {
      name = "unlockAndMount";
      runtimeInputs = with pkgs; [
        cryptsetup
        kdePackages.kdialog
        coreutils  # Für grundlegende Befehle wie mkdir
        util-linux # Für mount
	libnotify

      ];
      text = ''
export DISPLAY=:0
export XAUTHORITY=/home/tom/.Xauthority

UUID="fa2a1b43-fe24-4213-819f-a3e72d8020b3"
MAPPER_NAME="toshiba-2TB"
MOUNT_POINT="/run/media/toshiba-2TB"
DEVICE=$(blkid -o device -t UUID="$UUID")

while true; do
    PASSPHRASE=$(kdialog --password "Bitte geben Sie das Passwort fuer die verschluesselte Festplatte ein:")

    if [ -n "$PASSPHRASE" ]; then
        if echo "$PASSPHRASE" | cryptsetup luksOpen "$DEVICE" "$MAPPER_NAME"; then
            mkdir -p "$MOUNT_POINT"
            if systemd-mount --no-block /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"; then
                break
            else
                cryptsetup luksClose "$MAPPER_NAME"
            fi
        fi
    else
        exit 1
    fi
done
      '';
    };


monitorHook = pkgs.writeShellApplication {
  name = "monitorHook";
  runtimeInputs = with pkgs; [ kdePackages.kdialog coreutils systemd ];
  text = ''
    uid=$(id -u tom)
    export DISPLAY=:0
    export XAUTHORITY=/home/tom/.Xauthority
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
    export XDG_RUNTIME_DIR=/run/user/$uid
    export PATH="/etc/profiles/per-user/tom/bin:/run/current-system/sw/bin:$PATH"

    st=/sys/class/drm/card1-DP-2/status
    if [ -r "$st" ]; then
      status=$(cat "$st")
      if [ "$status" = "connected" ]; then
        if kdialog --yesno "Externer Monitor (DP-2) erkannt. Layout anwenden?"; then
          systemd-run --user --quiet --collect \
            -E DISPLAY="$DISPLAY" \
            -E XAUTHORITY="$XAUTHORITY" \
            -E DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            -E PATH="$PATH" \
            setup-monitor.sh monitor left-of extend
        fi
      elif [ "$status" = "disconnected" ]; then
        systemd-run --user --quiet --collect \
          -E DISPLAY="$DISPLAY" \
          -E XAUTHORITY="$XAUTHORITY" \
          -E DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
          -E PATH="$PATH" \
          setup-monitor.sh no-monitor
      fi
    fi
  '';

};

  phoneHook = pkgs.writeShellApplication {
    name = "phoneHook";
    runtimeInputs = with pkgs; [ coreutils systemd ];
    text = ''
      uid=$(id -u tom)
      export DISPLAY=:0
      export XAUTHORITY=/home/tom/.Xauthority
      export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
      export XDG_RUNTIME_DIR=/run/user/$uid
      export PATH="/etc/profiles/per-user/tom/bin:/run/current-system/sw/bin:$PATH"

      # phone-backup.sh soll in Toms PATH liegen (z.B. per Home-Manager/Profil installiert)
      # Seriennummer deines Phones wird als Argument übergeben:
      systemd-run --user --quiet --collect \
        -E DISPLAY="$DISPLAY" \
        -E XAUTHORITY="$XAUTHORITY" \
        -E DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        -E PATH="$PATH" \
        phone-backup.sh 3C181JEKB05184
    '';
  };


  in ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="fa2a1b43-fe24-4213-819f-a3e72d8020b3", RUN+="${pkgs.sudo}/bin/sudo -u root ${unlockAndMount}/bin/unlockAndMount"
    ACTION=="change", SUBSYSTEM=="drm", KERNEL=="card1",  RUN+="${pkgs.sudo}/bin/sudo -u tom ${monitorHook}/bin/monitorHook"
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device",ATTRS{idVendor}=="18d1", ATTRS{serial}=="3C181JEKB05184", RUN+="${pkgs.sudo}/bin/sudo -u tom ${phoneHook}/bin/phoneHook"
 '';



#  services.fprintd.enable = true;

#  services.fprintd.tod.enable = true;

#  services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix;


environment.etc."vpn.nordvpn.com.udp.ovpn".text = ''

client
dev tun
proto udp
remote 194.88.99.206 1194
resolv-retry infinite
remote-random
nobind
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
persist-key
persist-tun
ping 15
ping-restart 0
ping-timer-rem
reneg-sec 7200
comp-lzo no
verify-x509-name CN=de1175.nordvpn.com
pull-filter ignore "ifconfig-ipv6"
pull-filter ignore "route-ipv6"



remote-cert-tls server

auth-user-pass
verb 3
pull
fast-io
cipher AES-256-CBC
auth SHA512
<ca>
-----BEGIN CERTIFICATE-----
MIIFCjCCAvKgAwIBAgIBATANBgkqhkiG9w0BAQ0FADA5MQswCQYDVQQGEwJQQTEQ
MA4GA1UEChMHTm9yZFZQTjEYMBYGA1UEAxMPTm9yZFZQTiBSb290IENBMB4XDTE2
MDEwMTAwMDAwMFoXDTM1MTIzMTIzNTk1OVowOTELMAkGA1UEBhMCUEExEDAOBgNV
BAoTB05vcmRWUE4xGDAWBgNVBAMTD05vcmRWUE4gUm9vdCBDQTCCAiIwDQYJKoZI
hvcNAQEBBQADggIPADCCAgoCggIBAMkr/BYhyo0F2upsIMXwC6QvkZps3NN2/eQF
kfQIS1gql0aejsKsEnmY0Kaon8uZCTXPsRH1gQNgg5D2gixdd1mJUvV3dE3y9FJr
XMoDkXdCGBodvKJyU6lcfEVF6/UxHcbBguZK9UtRHS9eJYm3rpL/5huQMCppX7kU
eQ8dpCwd3iKITqwd1ZudDqsWaU0vqzC2H55IyaZ/5/TnCk31Q1UP6BksbbuRcwOV
skEDsm6YoWDnn/IIzGOYnFJRzQH5jTz3j1QBvRIuQuBuvUkfhx1FEwhwZigrcxXu
MP+QgM54kezgziJUaZcOM2zF3lvrwMvXDMfNeIoJABv9ljw969xQ8czQCU5lMVmA
37ltv5Ec9U5hZuwk/9QO1Z+d/r6Jx0mlurS8gnCAKJgwa3kyZw6e4FZ8mYL4vpRR
hPdvRTWCMJkeB4yBHyhxUmTRgJHm6YR3D6hcFAc9cQcTEl/I60tMdz33G6m0O42s
Qt/+AR3YCY/RusWVBJB/qNS94EtNtj8iaebCQW1jHAhvGmFILVR9lzD0EzWKHkvy
WEjmUVRgCDd6Ne3eFRNS73gdv/C3l5boYySeu4exkEYVxVRn8DhCxs0MnkMHWFK6
MyzXCCn+JnWFDYPfDKHvpff/kLDobtPBf+Lbch5wQy9quY27xaj0XwLyjOltpiST
LWae/Q4vAgMBAAGjHTAbMAwGA1UdEwQFMAMBAf8wCwYDVR0PBAQDAgEGMA0GCSqG
SIb3DQEBDQUAA4ICAQC9fUL2sZPxIN2mD32VeNySTgZlCEdVmlq471o/bDMP4B8g
nQesFRtXY2ZCjs50Jm73B2LViL9qlREmI6vE5IC8IsRBJSV4ce1WYxyXro5rmVg/
k6a10rlsbK/eg//GHoJxDdXDOokLUSnxt7gk3QKpX6eCdh67p0PuWm/7WUJQxH2S
DxsT9vB/iZriTIEe/ILoOQF0Aqp7AgNCcLcLAmbxXQkXYCCSB35Vp06u+eTWjG0/
pyS5V14stGtw+fA0DJp5ZJV4eqJ5LqxMlYvEZ/qKTEdoCeaXv2QEmN6dVqjDoTAo
k0t5u4YRXzEVCfXAC3ocplNdtCA72wjFJcSbfif4BSC8bDACTXtnPC7nD0VndZLp
+RiNLeiENhk0oTC+UVdSc+n2nJOzkCK0vYu0Ads4JGIB7g8IB3z2t9ICmsWrgnhd
NdcOe15BincrGA8avQ1cWXsfIKEjbrnEuEk9b5jel6NfHtPKoHc9mDpRdNPISeVa
wDBM1mJChneHt59Nh8Gah74+TM1jBsw4fhJPvoc7Atcg740JErb904mZfkIEmojC
VPhBHVQ9LHBAdM8qFI2kRK0IynOmAZhexlP/aT/kpEsEPyaZQlnBn3An1CRz8h0S
PApL8PytggYKeQmRhl499+6jLxcZ2IegLfqq41dzIjwHwTMplg+1pKIOVojpWA==
-----END CERTIFICATE-----
</ca>
key-direction 1
<tls-auth>
#
# 2048 bit OpenVPN static key
#
-----BEGIN OpenVPN Static key V1-----
e685bdaf659a25a200e2b9e39e51ff03
0fc72cf1ce07232bd8b2be5e6c670143
f51e937e670eee09d4f2ea5a6e4e6996
5db852c275351b86fc4ca892d78ae002
d6f70d029bd79c4d1c26cf14e9588033
cf639f8a74809f29f72b9d58f9b8f5fe
fc7938eade40e9fed6cb92184abb2cc1
0eb1a296df243b251df0643d53724cdb
5a92a1d6cb817804c4a9319b57d53be5
80815bcfcb2df55018cc83fc43bc7ff8
2d51f9b88364776ee9d12fc85cc7ea5b
9741c4f598c485316db066d52db4540e
212e1518a9bd4828219e24b20d88f598
a196c9de96012090e333519ae18d3509
9427e7b372d348d352dc4c85e18cd4b9
3f8a56ddb2e64eb67adfc9b337157ff4
-----END OpenVPN Static key V1-----
</tls-auth>
'';
  
  home-manager.users.tom = { pkgs, ... }: {
   home.packages = [ 
   pkgs.atool
   pkgs.httpie
   ];
   
   programs.bash = {
        enable = true;
        historySize=-1;
	historyFileSize=-1;
        historyControl = [ "ignoredups" ];

        initExtra = ''
  export GPG_TTY=$(tty)
  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  export EDITOR="nvim"


  # append to the history file, don't overwrite it
  shopt -s histappend

  # Ton deaktivieren im Terminal bei Fehler
  bind 'set bell-style none'
   
export PS1='\[\033[1;38;2;255;140;0m\]\u@\h\[\033[1;37m\]:\[\033[1;38;2;255;140;0m\]\w\[\033[00m\]\$ '
alias open='xdg-open'
alias gita='git add .'
alias gitc='git commit -m "c"'
alias gitp='git push'
alias gitf='git add . && git commit -m "c" && git push'
   '';
  };

  

  programs.neovim = {
    enable = true;
    extraConfig = ''
      lua << EOF
        -- Zeilennummern und relative Zeilennummern aktivieren
        vim.o.number = true
        vim.o.relativenumber = true

        -- Yank into system clipboard
        vim.keymap.set({'n', 'v'}, '<leader>y', '"+y') -- yank motion
        vim.keymap.set({'n', 'v'}, '<leader>Y', '"+Y') -- yank line

        -- Paste from system clipboard
        vim.keymap.set('n', '<leader>p', '"+p')  -- paste after cursor
        vim.keymap.set('n', '<leader>P', '"+P')  -- paste before cursor
      EOF
    ''; 
  };
  

  programs.git = {
    enable = true;
    userName  = "tombo09";
    userEmail = "regular.tb@gmail.com";
    extraConfig = {pull.rebase = false;};
  };

  programs.kitty = {
    enable = true;
        extraConfig = ''
      # Setzen Sie Ihre zusätzlichen Kitty-Konfigurationen hier
      enable_audio_bell no
      font_size 12
      background #000000
   '';
   };

  
  home.file.".config/betterlockscreen/betterlockscreenrc" = {
    text = ''
  locktext="Type password to unlock..."
           '';
    };


  home.file.".config/keepassxc/keepassxc.ini" = {
      text = ''
      [General]
      ConfigVersion=2
      OpenPreviousDatabasesOnStartup=true
  
      [Browser]
      CustomProxyLocation=
      Enabled=true
  
      [PasswordGenerator]
      AdditionalChars=
      ExcludedChars=
      Lenght=25
  
      [Security]
      LockDatabaseIdle=true
      LockDatabaseIdleSecond=240
    
      [SSHAgent]
      Enabled=true
  
      '';
    };



programs.gpg = {
    enable = true;
    publicKeys = [
      {
        text = '' 
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQGNBGYodEcBDAC8RcSPBVo04Gl9XuERysfNynaPltTJ5SI2lrKY7YQwpV3hnuyz
eeswgTiQ30dDmb6N/j0rLORhFshNVN+bD9iBg6yr1FOyOTvbH+M4GRsFemYVGmXk
rRCQ85tM+Yb/5OXIEXSf5Yk3cPfuEYF0B3C1nG8J4nF+u5WP5NFFQNzPEIdYfPVB
alSN2dCscFIhQo2f+MsrS8uTrdk0pRRN8CiznokanzAbr4hLv6xkPUH7LNKHGcR+
uqiC6KvcTJTTLBtOw6dilyLinmBF+qK6+jLmY8oxtFc+Ifdnv2S9udHgkeyyu0PQ
eccNXc2nFSpfSt3AmNhCHRD3bh/LK/j1abYSDDJJauTL3f+8WcSFFdmoJy+VlXB8
98LA3MIpekiLEyuSH6DE/cAIBDPWioCuyUjb+S5L1eC3aSukZjngOLwf0TexBwtg
UJhZX61Xb2ZudrRLcvSfrLS2xCNeQSyNnE8hOXmiNiCQ5JfkC6pK7ewKKy0UYkNV
YPqRVtyaGLBNTSEAEQEAAbQHdG9tYm8wOYkBzgQTAQoAOBYhBKEfcU/twp/GOcdi
EqBS3/vC5amcBQJmKHRHAhsDBQsJCAcCBhUKCQgLAgQWAgMBAh4BAheAAAoJEKBS
3/vC5amcpN0L/Rg2T4l8VA20+bwLSi/zQHnz7DUTytujIABJTs+IGXnWYbbICHTL
kfKKxGwczmEGlRi6JEqFRRy/zRHD8Je87aTLdnFsEuMlQfWzSJug1LH7YDxOIRG1
Q/FMobARXD3ddapwAZp62IbhESX7j+YQZi6lIJg5nKxMlTYSDOj+TP7Lm321Gl08
71TwXf2XFB6aBRma8iCQCvkN+YiIwm+xn5NIEyf79FbZ5kixMmjwsRhBDzuq1/dr
6/LF7nure80H0CTBRDPVUrQqNIosvZY95ZgD0rRvKWG5Fb4LU3JjnwMZDE4FPgMu
mbSW37txKAwh5ncUwHJAAwxA2zGlb9zmqOO40VWHCpY3ia6gdSvO/bQ3jAvAzVoK
4bvXvFd1wFYHOfa9qmTHo5AMrMAwB4gIEPSeR+YodY1V6r6ZlVpa5oywdftk+1ks
MJeCyV/m73vIB6tazYSGZs61YDgXbjaZWZMzIlJC2G9yo7pEklSdIHW6/HQrbKuJ
eMbcVzcnkjw4PLkBjQRmKHRHAQwA54vq3KKxcDpVC32mP2IABrQciwKGarIu6t77
jxIjuwF51u2S68nfL1tRNoecKZ2iB7dmBD5uFMELdFMKAmEjE8eRSrVzb5VFT11e
HBFei20i8G4tTxRGHDWI3Bf7I2Vr3vXgONPk0uNeFfi2vXV9SJA2clSXdLwZpO8e
yhGbrnX4ONrCxP0LKUTDXkvz21M9+2VOJATHku+Aq0oN9h9ZtjhbWAJ8JGYVbFEw
qc+6vR6Dd3fmBJMWUqXCVZv1tQ+5hBu3l9wrWosxRDR9ySToF0dkf7aWLQdS/DY9
+Roo3yehnORbr3qHcw6Zt4X/TINsaarYW1TUAGV6rHrWhc9PVfqMTdjJq7zKVjda
/gHywFpIfd3oJUznwU4oyHkpcoeQBawjQ51VFjGboIyJRJ2RiGj5QQ/ftkKFuR40
dP7OJ8DOKBnqokfisQzasO2UTjnpHcG760PZ1yitNm+T77oIJzEAyTQ5UF5mxzQH
gA0ydlyPZu2JJZVsX9InvzyD8VHVABEBAAGJAbYEGAEKACAWIQShH3FP7cKfxjnH
YhKgUt/7wuWpnAUCZih0RwIbDAAKCRCgUt/7wuWpnLCAC/9GUO34/4IRpl552biO
AoRHN6L91KlFnVnd1VJLJ66ArO+LSEGqiOyr6xghO9H9olSmn+MYnyXfiGK4xi1G
lQjQzZ3Di2H0B7OrTSFr5RJ7Kp9WNudv4QK5N6ryS9+BzyidZcQZ2za9NpcMJjwW
8nFEhxX/PK18Nf8WZtNJuzVCSgFFbuKMD21qEK385Jw2GflCVAjyevvIKHTtSoeG
P+QqyYS6hwbB9L/3+WW15402Nv+hcbqDf4O+2pThflSIaDGF7PjA/6cwKChxOr7Q
T7p9uNtf8ajXcrn/Qvl90cwu6h/nyYGHXPLZkxrXh/8NiN4r9IPYlcJnAfFvXDm2
nvzC2yD9zg+HOqtt191mM/1eyvoNff2PIZ1xPg2FWoiArREHNM0QgwvEJJxsaZ2a
OKyflNMbwTVJFNpJoB5+ysvDD8J2d5FKHRt+2uAMcAROx+s8YiYQRaspsONFZ6A2
wP/02qx1VzdEiLdevfSpco9lbLFLdwrR6Dc/6LNrosdYq9o=
=845V
-----END PGP PUBLIC KEY BLOCK-----
        '';
      }
      {
        text = ''
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQGNBGbG7BwBDADCXL4vB+6eSQYj14hYH+LcIpC4LeFjHoNpVcH5KqzEaoDOgOne
yPpzE17HFiOMOjBrrTZ0yl5eMBpkWx5hoUAnUHINUWfFZxc8VEq6ejrqWK4DBKir
MgPnQRS09+DEJRf2sCQFOgSiD/3vvMuthZysYuf7xyJwds1E7yucdfBfI3fqQEd6
QJL0xUy37CmgJWoQb9zlX+lCGUzW+nug4GIHS3xqqMny2fXvSI1aNRVS8xDSDY9E
n8JxNZGHn3x+x3Rx7MwW5TYmGauWF2ISt5/F2Pp5cmkp1+0XYKMcTBO09b6y16RP
pseDIBBJBTOXv8cd4hnvt3ZRluI/WOFqahCpoZ4t1j+V6jJWgp4TeCBX9vErhJHa
EhlrAetEh5AfrpUFKQiY0eGIpJzPy1pJ/lT19aigyfF8S33Ry0EhVx9YZmXmJ8Bz
MVR4qX6qfQodDu5KPiC+yKNl9NXudV3UPCbcT7g0p465Q6YzGMiA/O0IFtjBS6aW
5fnlcwvI//iBCykAEQEAAbQHdG9tYm8wOYkB0QQTAQgAOxYhBF0At6UqUxruPyMk
Lxv4QdZ9746wBQJmxuwcAhsDBQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheAAAoJ
EBv4QdZ9746wpRQL/0V5+//9CStzOlgIErTkUL2jcZ58AC162rIw43bEaby7ard5
KlYI74c+OcnT2OmTIt+rsGmeVSss79TStHv/tLs7qRm9AQaXBIX1Xw8v5ix6xO/R
hVKqZM9Dk5CD+eaGoDO+63/lSgFr/R7TWJi0dVeydMKqpOH2DI+lsSbmA+YT2EQ5
GMT59Nx2VEWkcucyem1bBKS8gFqwF+mKNXTY9NzvA7l77cA0ceKyqF/t8UuZr2mO
QAK7QmpJgkYzUBYsR5HWfeXK4EWs8Kc8/2A911BVl4/9yG9LTVdbV8u5SyzMrbYt
ZvgVWkkwXYtCXgTuwb9WE7EmWeyzLc0Vl6Ri49aDHw2FNPltsbUNbUTaGKjqNhwj
/Kzkzhm38YYZk+gS33CNNAlDbBMuhlsj92gL7cSlyx94Vse9Jq398qz+vuUJKmlw
bPycUtDEvwHrIdwHG6766Ia+hDCmIlQvxjUyfU0ifSNLZSSTStgFFIsx5R+9FO3g
/o2jUmk0u0gHnXa8ILkBjQRmxuxFAQwAnctE9EwhHusEh5/YYkVie+oieMgYH3x3
cr9+z6x+tUG8lCaJGdi3F3rGMmoQjS8VRsUDVzqfOgLdYlXnf8TLVvP/fPBTuHmH
nqZS9Pa7mB/WeovfT7d9ep7cpXGH4xajGK1omEiBsl55h+X5TUejCUj4xCHLWKH7
kIiFhACpFsDnrsy5XrXxmze9cJ4TlD+FtT471p1S9aPPCnGVUSSRdZcIfM4t4Yll
yFkXYchfcEjGRSkXyThQOLJ7UndGveyPj0FW9DxK5uokauYRBBFwIlZ98ULQ0FTI
n0xEvFz8sp2wKAJvdOoqXuXqbLbB6z+v3p20rrpr+YEMjaHAbwUxw1OFHf62AHeA
EMyC3m+F0gDnu5HgYV8YMjE/jCqHaM4C1atCTFGbjFDYjJlV6yFWCGs66b4H4TUM
EkulGT09sHQMk24V7a3/PPpI3KI1n63wn9C+i5g5ozHsl/IsUjDOQjzM20oMJTwn
9yphHEOXbRKv0cR8S0AIMz9x1Um6Hm4VABEBAAGJAbYEGAEIACAWIQRdALelKlMa
7j8jJC8b+EHWfe+OsAUCZsbsRQIbDAAKCRAb+EHWfe+OsHsyC/9uZzzzTSz2LYnT
EBbks+/t2vtPpWYPxu8cVdOOqlrdeStjKGp16ZpwmG86A6NtA5tSVNt2crj/04en
bXzGNPWkFjOXQT8JwKDUoqfudHVoauRmQeVMBbr0f4lF9vyys3oI+40/iIlozC8C
YMzKsTV3Td69HKg4SZuVPpjp0ni75dh2nputa2PksuR7x2iwN+lSpVpFntNAQHIl
O+lxJ92K3a2t/uN/iZ/bffsGTDbC7+iFOUDijos1rNcdQLKhNv5SBBzld4FXbpYv
P4EEZKLj7GpQenkoA2wY+KWaqFlgL2mi4t8JbuL0wWSIzCKC3qKSC4bm7F3NJMji
Dyxm/ZZvjDE0Q+49NcBcLcsd+hz+x01M3+Efu9mZ5e5JtwTJmEndtyp5cPQXJBmU
X3CsQyQAC/orpDnROsR7AmQJbR94j5lw+JZfLe+pnqUMfppCUvb49hAwknDWJ/iw
ibmI1qEQL8Xfetag4dYIY5Hji+e7XO8XxE2JE6B+m4oIe0YOljc=
=QN+e
-----END PGP PUBLIC KEY BLOCK-----
        '';
      }
    ];
  };




  services.polybar = {
enable = true;
    package = pkgs.polybar.override {
      pulseSupport = true;  # Enable PulseAudio support
    };

script = ''
#!/usr/bin/env bash
# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 and bar2
#echo "---" | tee -a /tmp/polybar.log /tmp/polybar.log
#polybar bar 2>&1 | tee -a /tmp/polybar.log & disown

#echo "Bars launched..."

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload bar &
  done
else
  polybar --reload bar &
fi

'';

extraConfig = ''
;==========================================================
;
;
;   ██████╗  ██████╗ ██╗  ██╗   ██╗██████╗  █████╗ ██████╗
;   ██╔══██╗██╔═══██╗██║  ╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
;   ██████╔╝██║   ██║██║   ╚████╔╝ ██████╔╝███████║██████╔╝
;   ██╔═══╝ ██║   ██║██║    ╚██╔╝  ██╔══██╗██╔══██║██╔══██╗
;   ██║     ╚██████╔╝███████╗██║   ██████╔╝██║  ██║██║  ██║
;   ╚═╝      ╚═════╝ ╚══════╝╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
;
;
;   To learn more about how to configure Polybar
;   go to https://github.com/polybar/polybar
;
;   The README contains a lot of information
;
;==========================================================

[colors]
background = #000000
background-alt = #373B41
foreground = #C5C8C6
#;foregroud = #ffffff
primary = #ffffff
secondary = #8ABEB7
alert = #A54242
disabled = #707880

[bar/bar]
width = 100%
height = 24pt
radius = 6
monitor = ''${env:MONITOR:}

; dpi = 96

background = ''${colors.background}
foreground = ''${colors.foreground}

line-size = 3pt

border-size = 0pt
border-color = #00000000

padding-left = 0
padding-right = 1

module-margin = 1

separator = |
separator-foreground = ''${colors.disabled}

font-0 = monospace;2
font-1 = "Font Awesome 5 Brands:style=Regular:pixelsize=14;1"
font-2 = "Font Awesome 6 Free:style=Regular:pixelsize=14;1"
font-3 = "Font Awesome 6 Free Solid:style=Solid:pixelsize=14;1"
font-4 = "Font Awesome 6 Brands:style=Regular:pixelsize=14;1"


modules-left = xworkspaces menu-apps
modules-center = date
modules-right = scalp vpn pulseaudio network memory battery
cursor-click = pointer
cursor-scroll = ns-resize

enable-ipc = true

; wm-restack = generic
; wm-restack = bspwm
; wm-restack = i3

; override-redirect = true


;
;

[module/vpn]
type = custom/script
exec = vpn-status.sh
click-left = vpn-toggle.sh
interval = 2
format-prefix = "VPN: "
format = <label>
label = %output%


[module/scalp]
type = custom/script
exec = /home/tom/.config/polybar-position-exe.sh
interval = 1 
label = %output%
click-left = bash -c 'kitty sh -ic "sudo sh -c \\"if [ -f /tmp/option1_status ]; then rm /tmp/option1_status; else echo on > /tmp/option1_status; fi\\" "'
click-right = echo -e "Ctrl + Alt + b\\tLong limit_loop\\nCtrl + Alt + s\\tShort limit_loop\\nAlt + Shift + b\\tLong market\\nAlt + Shift + s\\tShort market\\nAlt + Shift + Ctrl + s\\tClose Short All market\\nAlt + Shift + Ctrl + b\\tClose Long All market\\nShift + Ctrl + Tab + s\\tClose Short 0.005 market\\nCtrl + Shift + Tab + b\\tClose Long 0.005 market\\nCtrl + Tab + s\\tClose Short All limit_loop\\nCtrl + Tab + b\\tClose Long All limit_loop" | rofi -dmenu -p "Shortcuts"
;
;



[module/systray]
type = internal/tray

format-margin = 8pt
tray-spacing = 16pt

[module/xworkspaces]
type = internal/xworkspaces

pin-workspaces = true

label-active = %name%
label-active-background = ''${colors.background-alt}
label-active-underline= ''${colors.primary}
label-active-padding = 1

label-active-foreground = ''${colors.primary}

label-occupied = %name%
label-occupied-padding = 1

label-occupied-foreground = ''${colors.primary}

label-urgent = %name%
label-urgent-background = ''${colors.alert}
label-urgent-padding = 1

label-empty = %name%
label-empty-foreground = ''${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:60:...%

[module/filesystem]
type = internal/fs
interval = 25

mount-0 = /

label-mounted = %{F#F0C674}%mountpoint%%{F-} %percentage_used%%

label-unmounted = %mountpoint% not mounted
label-unmounted-foreground = ''${colors.disabled}

[module/pulseaudio]
type = internal/pulseaudio

;format-volume-prefix = "VOL "
format-volume-prefix-foreground = ''${colors.primary}
;format-volume = <label-volume>
format-volume-foreground = ''${colors.primary}

label-volume = %percentage%%

;label-muted = muted
label-muted =  muted
;label-muted-foreground = ''${colors.disabled}

; Available tags:
;   <label-volume> (default)
;   <ramp-volume>
;   <bar-volume>
format-volume = <ramp-volume> <label-volume>

; Available tags:
;   <label-muted> (default)
;   <ramp-volume>
;   <bar-volume>
;format-muted = <label-muted>

; Available tokens:
;   %percentage% (default)
;   %decibels%
;label-volume = %percentage%%

; Available tokens:
;   %percentage% (default)
;   %decibels%
;label-muted = 🔇 muted
label-muted-foreground = #666

; Only applies if <ramp-volume> is used
ramp-volume-0 = 
ramp-volume-1 = 
ramp-volume-2 = 

; Right and Middle click
click-right = pavucontrol
; click-middle = 

[module/xkeyboard]
type = internal/xkeyboard
blacklist-0 = num lock

label-layout = %layout%
label-layout-foreground = ''${colors.primary}

label-indicator-padding = 2
label-indicator-margin = 1
label-indicator-foreground = ''${colors.background}
label-indicator-background = ''${colors.secondary}

[module/memory]
type = internal/memory
interval = 2
format-prefix = "RAM "
format-prefix-foreground = ''${colors.primary}
label = %percentage_used:2%%
label-foreground = ''${colors.primary} 

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "CPU "
format-prefix-foreground = ''${colors.primary}
label = %percentage:2%%

[network-base]
type = internal/network
interval = 5
format-connected = <label-connected>
format-disconnected = <label-disconnected>
label-disconnected = %{F#F0C674}%ifname%%{F#707880} disconnected


[module/wlan]
inherit = network-base
interface-type = wireless
label-connected =  %essid%
#;label-connected = %{F#F0C674}%ifname%%{F-} %essid% %local_ip%
label-connected-foreground = ''${colors.primary}


[module/eth]
inherit = network-base
interface-type = wired
label-connected = %{F#F0C674}%ifname%%{F-} %local_ip%

[module/date]
type = internal/date
interval = 1

date = %d.%m %H:%M
date-alt = %A %d.%m.20%y %H:%M:%S

label = %date%
label-foreground = ''${colors.primary}

[settings]
screenchange-reload = true
pseudo-transparency = true



[module/battery]
type = internal/battery

; This is useful in case the battery never reports 100% charge
; Default: 100
full-at = 100

; format-low once this charge percentage is reached
; Default: 10
; New in version 3.6.0
low-at = 5

; Use the following command to list batteries and adapters:
; $ ls -1 /sys/class/power_supply/
battery = BAT0
adapter = ADP1

; If an inotify event haven't been reported in this many
; seconds, manually poll for new values.
;
; Needed as a fallback for systems that don't report events
; on sysfs/procfs.
;
; Disable polling by setting the interval to 0.
;
; Default: 5
poll-interval = 1

; see "man date" for details on how to format the time string
; NOTE: if you want to use syntax tags here you need to use %%{...}
; Default: %H:%M:%S
time-format = %H:%M

; Available tags:
;   <label-charging> (default)
;   <bar-capacity>
;   <ramp-capacity>
;   <animation-charging>
format-charging = <animation-charging> <label-charging>
;format-charging = <label-charging>

; Available tags:
;   <label-discharging> (default)
;   <bar-capacity>
;   <ramp-capacity>
;   <animation-discharging>
format-discharging = <ramp-capacity> <label-discharging>

; Available tags:
;   <label-full> (default)
;   <bar-capacity>
;   <ramp-capacity>
format-full = <ramp-capacity> <label-full>

; Format used when battery level drops to low-at
; If not defined, format-discharging is used instead.
; Available tags:
;   <label-low>
;   <animation-low>
;   <bar-capacity>
;   <ramp-capacity>
; New in version 3.6.0
format-low = <animation-low> <label-low>
;format-low = <animation-low>

; Available tokens:
;   %percentage% (default) - is set to 100 if full-at is reached
;   %percentage_raw%
;   %time%
;   %consumption% (shows current charge rate in watts)
;label-charging = Charging %percentage%%
;label-charging =  %percentage%%
label-charging = %percentage%%
label-charging-foreground = ''${colors.primary}

; Available tokens:
;   %percentage% (default) - is set to 100 if full-at is reached
;   %percentage_raw%
;   %time%
;   %consumption% (shows current discharge rate in watts)
;label-discharging = Discharging %percentage%%
label-discharging = %percentage%%
label-discharging-foreground = ''${colors.primary}

; Available tokens:
;   %percentage% (default) - is set to 100 if full-at is reached
;   %percentage_raw%
label-full = %percentage_raw%%
label-full-foreground = ''${colors.primary}

; Available tokens:
;   %percentage% (default) - is set to 100 if full-at is reached
;   %percentage_raw%
;   %time%
;   %consumption% (shows current discharge rate in watts)
; New in version 3.6.0
;label-low = BATTERY LOW
label-low = %percentage%%

; Only applies if <ramp-capacity> is used
ramp-capacity-0 = 
ramp-capacity-1 = 
ramp-capacity-2 = 
ramp-capacity-3 = 
ramp-capacity-4 = 

; Only applies if <bar-capacity> is used
bar-capacity-width = 10

; Only applies if <animation-charging> is used
animation-charging-0 = 
animation-charging-1 = 
animation-charging-2 = 
animation-charging-3 = 
animation-charging-4 = 
; Framerate in milliseconds
animation-charging-framerate = 750

; Only applies if <animation-discharging> is used
animation-discharging-0 = 
animation-discharging-1 = 
animation-discharging-2 = 
animation-discharging-3 = 
animation-discharging-4 = 
; Framerate in milliseconds
animation-discharging-framerate = 500

; Only applies if <animation-low> is used
; New in version 3.6.0
animation-low-0 = ! 
animation-low-1 = 
animation-low-framerate = 1000


[module/menu-apps]
type = custom/menu
expand-right = true

label-open = 
label-close = X
label-separator = |
format-spacing = 1

menu-0-0 = 
menu-0-0-exec = sh -c 'echo -e "firefox\\nobsidian\\nspotify\\nkitty\\nyubioath-flutter\\nkeepassxc\\nanki\\ncode\\nidea-ultimate\\nVirtualBox\\nnmtui\\nnetworkmanager_dmenu\\nblueman-manager\\npavucontrol\\narandr" | dmenu -i -p "Run: " | xargs -r -I {} sh -c "{} &"'
menu-0-1 = 
menu-0-1-exec = menu-open-1
menu-0-2 =  
menu-0-2-exec = kitty ranger 
menu-0-3 =  
menu-0-3-exec = kitty -e nmtui
menu-0-4 = 
menu-0-4-exec = blueman-manager &
menu-0-5 = 
menu-0-5-exec = pavucontrol &
menu-0-6 = 
menu-0-6-exec = menu-open-3
menu-0-7 = 
menu-0-7-exec = menu-open-4
menu-0-8 =   
menu-0-8-exec = menu-open-5
menu-0-9 = 
menu-0-9-exec = menu-open-6
menu-0-10 = 
menu-0-10-exec = menu-open-7
menu-0-11 = 
menu-0-11-exec = menu-open-2



menu-7-3 = update-system
menu-7-3-exec = sh -c 'kitty bash -lc "update-system.sh; exec bash -i"'
menu-7-1 = Camera
menu-7-1-exec = menu-open-9
menu-7-2 = Microphone
menu-7-2-exec = menu-open-10
menu-9-0 = An
menu-9-0-exec = bash -lc 'p=$(kdialog --password "sudo: Kamera aktivieren"); [ -n "$p" ] && echo "$p" | sudo -S modprobe uvcvideo && notify-send -t 4000 "Kamera" "Aktiviert" || notify-send -t 4000 "Kamera" "Fehlgeschlagen"'
menu-9-1 = Aus
menu-9-1-exec = bash -lc 'p=$(kdialog --password "sudo: Kamera deaktivieren"); [ -n "$p" ] && echo "$p" | sudo -S modprobe -r uvcvideo && notify-send -t 4000 "Kamera" "Deaktiviert" || notify-send -t 4000 "Kamera" "Fehlgeschlagen"'
menu-10-0 = An
menu-10-0-exec = pactl set-source-mute @DEFAULT_SOURCE@ 0 && notify-send -t 4000 "Mikrofon" "Aktiviert" || notify-send -t 4000 "Mikrofon" "Fehlgeschlagen"
menu-10-1 = Aus
menu-10-1-exec = pactl set-source-mute @DEFAULT_SOURCE@ 1 && notify-send -t 4000 "Mikrofon" "Deaktiviert" || notify-send -t 4000 "Mikrofon" "Fehlgeschlagen"


menu-2-6 = Reboot
menu-2-6-exec = systemctl reboot
menu-2-7 = Shutdown
menu-2-7-exec = systemctl poweroff
menu-2-1 = Logout (i3)
menu-2-1-exec = i3-msg exit
menu-2-0 = Lock
menu-2-0-exec = betterlockscreen -l
menu-2-5 = Hibernate
menu-2-5-exec = systemctl hibernate
menu-2-3 = Suspend-then-Hibernate
menu-2-3-exec = systemctl suspend-then-hibernate
menu-2-4 = Hybrid-Sleep
menu-2-4-exec = systemctl hybrid-sleep
menu-2-2 = Suspend
menu-2-2-exec = systemctl suspend



menu-3-0 = Slider
menu-3-0-exec = bash -lc 'val=$(kdialog --slider "Helligkeit" 0 100 1); [ -n "$val" ] && brightnessctl set "''${val}%"'
menu-3-1 = +
menu-3-1-exec = brightnessctl set +10%
menu-3-2 = -
menu-3-2-exec = brightnessctl set 10%-
menu-3-3 = Nightshift
menu-3-3-exec = systemctl --user --quiet is-active redshift && systemctl --user stop redshift || systemctl --user start redshift

menu-1-0 = 
menu-1-0-exec = kitty
menu-1-1 = 
menu-1-1-exec = spotify &
menu-1-2 = 
menu-1-2-exec = firefox &
menu-1-3 = Obsidian
menu-1-3-exec = obsidian &
menu-1-4 = Yubikey-Auth
menu-1-4-exec = yubioath-flutter &
menu-1-5 = keepassxc
menu-1-5-exec = keepassxc &
menu-1-6 = Anki
menu-1-6-exec = anki-bin &
menu-1-7 = Vscode
menu-1-7-exec = code &
menu-1-8 = Intellij
menu-1-8-exec = idea-ultimate &
menu-1-9 = VirtualBox
menu-1-9-exec = VirtualBox &



menu-4-0 = settings
menu-4-0-exec = arandr &
menu-4-1 = monitor (l) ext
menu-4-1-exec = setup-monitor.sh monitor left-of extend &
menu-4-2 = monitor (l) mir
menu-4-2-exec = setup-monitor.sh monitor left-of mirror &
menu-4-3 = monitor (r) ext
menu-4-3-exec = setup-monitor.sh monitor right-of extend &
menu-4-4 = monitor (r) mir
menu-4-4-exec = setup-monitor.sh monitor right-of mirror &
menu-4-5 = no monitor
menu-4-5-exec = setup-monitor.sh no-monitor &

menu-5-0 = file full 
menu-5-0-exec = sh -c 'LC_TIME=de_DE.UTF-8 maim "/home/$USER/Pictures/screenshots/screenshot_$(date +'%d-%m-%Y_%Hh-%Mm-%Ss').png"'
menu-5-1 = file wdw 
menu-5-1-exec = maim --window $(xdotool getactivewindow) | xclip -selection clipboard -t image/png
menu-5-2 = file sel 
menu-5-2-exec = sh -c 'LC_TIME=de_DE.UTF-8 maim --select "/home/$USER/Pictures/screenshots/screenshot_$(date +'%d-%m-%Y_%Hh-%Mm-%Ss').png"'
menu-5-3 = cpb full 
menu-5-3-exec = maim | xclip -selection clipboard -t image/png 
menu-5-4 = cpb wdw 
menu-5-4-exec = maim --window $(xdotool getactivewindow) | xclip -selection clipboard -t image/png
menu-5-5 = cpb sel 
menu-5-5-exec = maim --select | xclip -selection clipboard -t image/png 

menu-6-1 = eject Toshiba-2TB
menu-6-1-exec = eject-extdisc.sh
menu-6-2 = backup phone
menu-6-2-exec = phone-backup.sh
menu-6-0 = backup Toshiba-2TB
menu-6-0-exec = backup-home.sh

menu-7-0 = privacy-mode
menu-7-0-exec = menu-open-8

menu-8-0 = Rechteck hinzufügen
menu-8-0-exec = create-rectangle
menu-8-1 = Mode beenden
menu-8-1-exec = pkill -f rectangle.py


[module/network]
type = internal/network
; Name of the network interface to display. You can get the names of the
; interfaces on your machine with `ip link`
; Wireless interfaces often start with `wl` and ethernet interface with `eno` or `eth`
interface =  

; If no interface is specified, polybar can detect an interface of the given type.
; If multiple are found, it will prefer running interfaces and otherwise just
; use the first one found.
; Either 'wired' or 'wireless'
; New in version 3.6.0
interface-type = wireless

; Seconds to sleep between updates
; Default: 1
interval = 3.0

; NOTE: Experimental (might change or be removed in the future)
; Test connectivity every Nth update by pinging 8.8.8.8
; In case the ping fails 'format-packetloss' is used until the next ping
; A value of 0 disables the feature
; Default: 0
;ping-interval = 3

; @deprecated: Define min width using token specifiers (%downspeed:min% and %upspeed:min%)
; Minimum output width of upload/download rate
; Default: 3
udspeed-minwidth = 5

; Accumulate values from all interfaces
; when querying for up/downspeed rate
; Default: false
accumulate-stats = true

; Consider an `UNKNOWN` interface state as up.
; Some devices like USB network adapters have 
; an unknown state, even when they're running
; Default: false
unknown-as-up = true

; The unit used for displaying network speeds
; For example if set to the empty string, a speed of 5 KB/s is displayed as 5 K
; Default: B/s
; New in version 3.6.0
speed-unit = ' '

; Available tags:
;   <label-connected> (default)
;   <ramp-signal>
;format-connected = <ramp-signal> <label-connected>
format-connected = <label-connected>

; Available tags:
;   <label-disconnected> (default)
format-disconnected = <label-disconnected>

; Used when connected, but ping fails (see ping-interval)
; Available tags:
;   <label-connected> (default)
;   <label-packetloss>
;   <animation-packetloss>
format-packetloss = <animation-packetloss> <label-connected>

; All labels support the following tokens:
;   %ifname%    [wireless+wired]
;   %local_ip%  [wireless+wired]
;   %local_ip6% [wireless+wired]
;   %essid%     [wireless]
;   %signal%    [wireless]
;   %upspeed%   [wireless+wired]
;   %downspeed% [wireless+wired]
;   %netspeed%  [wireless+wired] (%upspeed% + %downspeed%) (New in version 3.6.0)
;   %linkspeed% [wired]
;   %mac%       [wireless+wired] (New in version 3.6.0)

; Default: %ifname% %local_ip%
;label-connected = %essid% %signal%%
label-connected = %essid%
label-connected-foreground = ''${colors.primary}

; Default: (none)
label-disconnected = not connected
label-disconnected-foreground = ''${colors.primary}

; Default: (none)
;label-packetloss = %essid%
;label-packetloss-foreground = #eefafafa

; Only applies if <ramp-signal> is used
ramp-signal-0 = "|"
ramp-signal-1 = "||"
ramp-signal-2 = "|||"
ramp-signal-3 = "||||"
ramp-signal-4 = "|||||"
ramp-signal-5 = "||||||"

; Only applies if <animation-packetloss> is used
animation-packetloss-0 = ⚠
animation-packetloss-0-foreground = #ffa64c
animation-packetloss-1 = 📶
animation-packetloss-1-foreground = #000000
; Framerate in milliseconds
animation-packetloss-framerate = 500

[module/backlight]
type = internal/backlight

; Use the following command to list available cards:
; $ ls -1 /sys/class/backlight/
; Default: first usable card in /sys/class/backlight (new in version 3.7.0)
card = intel_backlight

; Use the `/sys/class/backlight/.../actual-brightness` file
; rather than the regular `brightness` file.
; New in version 3.6.0
; Changed in version: 3.7.0: Defaults to true also on amdgpu backlights
; Default: true
use-actual-brightness = true

; Interval in seconds after which after which the current brightness is read
; (even if no update is detected).
; Use this as a fallback if brightness updates are not registering in polybar
; (which happens if the use-actual-brightness is false).
; There is no guarantee on the precisio of this timing.
; Set to 0 to turn off
; New in version 3.7.0
; Default: 0 (5 if use-actual-brightness is false)
poll-interval = 0

; Enable changing the backlight with the scroll wheel
; NOTE: This may require additional configuration on some systems. Polybar will
; write to `/sys/class/backlight/''${self.card}/brightness` which requires polybar
; to have write access to that file.
; DO NOT RUN POLYBAR AS ROOT. 
; The recommended way is to add the user to the
; `video` group and give that group write-privileges for the `brightness` file.
; See the ArchWiki for more information:
; https://wiki.archlinux.org/index.php/Backlight#ACPI
; Default: false
enable-scroll = true

; Interval for changing the brightness (in percentage points).
; New in version 3.7.0
; Default: 5
scroll-interval = 10

; Available tags:
;   <label> (default)
;   <ramp>
;   <bar>
format = <label>

; Available tokens:
;   %percentage% (default)
label =  %percentage%%

; Only applies if <ramp> is used
ramp-0 = 🌕
ramp-1 = 🌔
ramp-2 = 🌓
ramp-3 = 🌒
ramp-4 = 🌑

; Only applies if <bar> is used
bar-width = 10
bar-indicator = |
bar-fill = ─
bar-empty = ─

; vim:ft=dosini


'';
};


  xsession.windowManager.i3 = {
    enable = true;
    config = {
floating = {
border = 2;
modifier = "Mod4";
};
bars = [];
modes = {};
keybindings = {};
focus = {
mouseWarping = true;
wrapping = "yes";
followMouse = true;
newWindow = "smart";
};
window = {
border = 2;
hideEdgeBorders = "none";
commands = [];
};
colors = {
focused = {
  border = "#000000";            # Rahmenfarbe
  background = "#707880";        # Hintergrundfarbe
  text = "#000000";              # Textfarbe
  indicator = "#1c1c1c";         # Indikatorfarbe
  childBorder = "#707880";       # Farbe des Kinderrahmens
};

unfocused = {
  border = "#000000";            # Rahmenfarbe
  background = "#1c1c1c";        # Hintergrundfarbe
  text = "#000000";              # Textfarbe
  indicator = "#000000";         # Indikatorfarbe
  childBorder = "#1c1c1c";       # Farbe des Kinderrahmens
};

focusedInactive = {
  border = "#000000";            # Rahmenfarbe
  background = "#1c1c1c";        # Hintergrundfarbe
  text = "#000000";              # Textfarbe
  indicator = "#000000";         # Indikatorfarbe
  childBorder = "#1c1c1c";       # Farbe des Kinderrahmens
};

urgent = {
  border = "#000000";            # Rahmenfarbe
  background = "#FFFFFF";        # Hintergrundfarbe
  text = "#1c1c1c";              # Textfarbe
  indicator = "#000000";         # Indikatorfarbe
  childBorder = "#FFFFFF";       # Farbe des Kinderrahmens
};

placeholder = {
  border = "#000000";            # Rahmenfarbe (wird ignoriert)
  background = "#1c1c1c";        # Hintergrundfarbe
  text = "#FFFFFF";              # Textfarbe
  indicator = "#000000";         # Indikatorfarbe (wird ignoriert)
  childBorder = "#1c1c1c";       # Farbe des Kinderrahmens (wird ignoriert)
};
background = "#000000";
};

fonts = {
  names = [ "DejaVu Sans Mono" "FontAwesome5Free" ];
  style = "Bold Semi-Condensed";
  size = 12.0;
};
workspaceLayout = "default";
defaultWorkspace = "workspace number 1";
	};
    extraConfig = ''
# This file has been auto-generated by i3-config-wizard(1).
# It will not be overwritten, so edit it as you like.
#
# Should you change your keyboard layout some time, delete
# this file and re-run i3-config-wizard(1).
#

# i3 config file (v4)
#
# Please see https://i3wm.org/docs/userguide.html for a complete reference!

set $mod Mod4

# Font for window titles. Will also be used by the bar unless a different font
# is used in the bar {} block below.
#font pango:monospace 12

# This font is widely installed, provides lots of unicode glyphs, right-to-left
# text rendering and scalability on retina/hidpi displays (thanks to pango).
#font pango:DejaVu Sans Mono 8

# Start XDG autostart .desktop files using dex. See also
# https://wiki.archlinux.org/index.php/XDG_Autostart
exec --no-startup-id dex --autostart --environment i3

# The combination of xss-lock, nm-applet and pactl is a popular choice, so
# they are included here as an example. Modify as you see fit.

# xss-lock grabs a logind suspend inhibit lock and will use i3lock to lock the
# screen before suspend. Use loginctl lock-session to lock your screen.
#exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork
exec --no-startup-id xss-lock --transfer-sleep-lock -- betterlockscreen -l 

# NetworkManager is the most popular way to manage wireless networks on Linux,
# and nm-applet is a desktop environment-independent system tray GUI for it.
exec --no-startup-id nm-applet

# Use pactl to adjust volume in PulseAudio.
set $refresh_i3status killall -SIGUSR1 i3status
#bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10% && $refresh_i3status
#bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10% && $refresh_i3status

bindsym XF86AudioRaiseVolume exec --no-startup-id pamixer -i 10 && killall -SIGUSR1 i3status
bindsym XF86AudioLowerVolume exec --no-startup-id pamixer -d 10 && killall -SIGUSR1 i3status
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && $refresh_i3status
bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle && $refresh_i3status

# Use Mouse+$mod to drag floating windows to their wanted position
floating_modifier $mod

# move tiling windows via drag & drop by left-clicking into the title bar,
# or left-clicking anywhere into the window while holding the floating modifier.
tiling_drag modifier titlebar

# start a terminal
bindsym $mod+Return exec kitty

# kill focused window
bindsym $mod+Shift+q kill

# A more modern dmenu replacement is rofi:
# bindcode $mod+40 exec "rofi -modi drun,run -show drun"
# There also is i3-dmenu-desktop which only displays applications shipping a
# .desktop file. It is a wrapper around dmenu, so you need that installed.
# bindcode $mod+40 exec --no-startup-id i3-dmenu-desktop

# change focus
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# alternatively, you can use the cursor keys:
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# move focused window
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# alternatively, you can use the cursor keys:
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# split in horizontal orientation
bindsym $mod+h split h

# split in vertical orientation
bindsym $mod+v split v

# enter fullscreen mode for the focused container
bindsym $mod+f fullscreen toggle

# change container layout (stacked, tabbed, toggle split)
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# focus the parent container
bindsym $mod+a focus parent

# focus the child container
#bindsym $mod+d focus child

# Define names for default workspaces for which we configure key bindings later on.
# We use variables to avoid repeating the names in multiple places.
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# switch to workspace
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

# move focused container to workspace
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# reload the configuration file
bindsym $mod+Shift+c reload
# restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
bindsym $mod+Shift+r restart
# exit i3 (logs you out of your X session)
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'"

# resize window (you can also use the mouse for that)
mode "resize" {
        # These bindings trigger as soon as you enter the resize mode

        # Pressing left will shrink the window’s width.
        # Pressing right will grow the window’s width.
        # Pressing up will shrink the window’s height.
        # Pressing down will grow the window’s height.
        bindsym j resize shrink width 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize shrink height 10 px or 10 ppt
        bindsym semicolon resize grow width 10 px or 10 ppt

        # same bindings, but for the arrow keys
        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt

        # back to normal: Enter or Escape or $mod+r
        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
}

bindsym $mod+r mode "resize"





#bindsym $mod+b exec --no-startup-id dmenu_run
#exec xautolock -time 3 -locker "betterlockscreen -l"

#exec --no-startup-id xautolock -time 6 -locker "betterlockscreen -l" -corners -00- -detectsleep 
exec --no-startup-id feh --bg-scale ~/.config/background.jpg
exec --no-startup-id betterlockscreen -u ~/.config/background.jpg
exec_always launch-polybar.sh
#exec --no-startup-id xidlehook --not-when-fullscreen --timer 180 'betterlockscreen -l' ' ' 
bindsym Mod1+l exec betterlockscreen -l

# Farben definieren
set $red #FF0000
set $green #00FF00
set $blue #0000FF
set $yellow #FFFF00
set $white #FFFFFF
set $black #000000
set $light-grey #C5C8C6
set $medium-grey #707880
set $dark-grey #1c1c1c

# Farben für verschiedene Fensterzustände
#client.focused          $black $medium-grey $black $dark-grey $medium-grey
#client.unfocused        $black $dark-grey $black $black $dark-grey
#client.focused_inactive $black $dark-grey $black $black $dark-grey
#client.urgent           $black $white $dark-grey $black $white
#client.placeholder      $black $dark-grey $white $black $dark-grey

bindsym $mod+Shift+p workspace prev
#bindsym $mod+Shift+n workspace next

#Hide window title bar
default_border pixel 2
default_floating_border pixel 2
for_window [class="^.*"] border pixel 2

# Wechselt zu einem neuen Workspace
bindsym $mod+Shift+n workspace t

# Helligkeit reduzieren
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 10%-

# Helligkeit erhöhen
bindsym XF86MonBrightnessUp exec --no-startup-id brightnessctl set +10%

bindsym $mod+Tab workspace back_and_forth

# Tastatur Helligkeit aktivieren
bindsym F6 exec --no-startup-id brightnessctl -d tpacpi::kbd_backlight s 2

# Tastatur Helligkeit deaktivieren
bindsym F5 exec --no-startup-id brightnessctl -d tpacpi::kbd_backlight s 0 

# move workspace to left and right monitors
bindsym $mod+Shift+bracketleft move workspace to output left
bindsym $mod+Shift+bracketright move workspace to output right



# Set touchpad sensitivity
#exec --no-startup-id xinput --set-prop 9 "libinput Accel Speed" 0.35


# dmenu nur mit spezifischen Eintragen
bindsym $mod+d exec --no-startup-id sh -c 'echo -e "firefox\\nobsidian\\nspotify\\nkitty\\nyubioath-flutter\\nkeepassxc\\nanki\\ncode\\nidea-ultimate\\nVirtualBox\\nnmtui\\nnetworkmanager_dmenu\\nblueman-manager\\npavucontrol\\narandr" | dmenu -i -p "Run: " | xargs -r -I {} sh -c "{} &"'


# shortcuts fur Anwendungen
#bindsym $mod+Shift+s exec --no-startup-id spotify
#bindsym $mod+Shift+o exec --no-startup-id obsidian
#bindsym $mod+Shift+f exec --no-startup-id firefox
assign [class="Spotify"] 1
assign [class="obsidian"] 2
assign [class="firefox"] 3

exec --no-startup-id spotify 
exec --no-startup-id obsidian
exec --no-startup-id firefox 

bindsym $mod+Shift+s workspace number $ws1
bindsym $mod+Shift+o workspace number $ws2
bindsym $mod+Shift+f workspace number $ws3


bindsym $mod+p exec playerctl play-pause
bindsym $mod+o exec playerctl next
bindsym $mod+i exec playerctl previous 



for_window [class="firefox"] border pixel 0
for_window [class="Spotify"] border pixel 0
for_window [class="obsidian"] border pixel 0

for_window [class="Spotify"] move to workspace number 1
for_window [class="obsidian"] move to workspace number 2
for_window [class="firefox"] move to workspace number 3

bindsym $mod+Shift+m exec --no-startup-id setup-monitor.sh monitor left-of extend &
bindsym $mod+m exec --no-startup-id setup-monitor.sh no-monitor &


# Screenshots
bindsym $mod+Print exec --no-startup-id sh -c 'LC_TIME=de_DE.UTF-8 maim "/home/$USER/Pictures/screenshots/screenshot_$(date +'%d-%m-%Y_%Hh-%Mm-%Ss').png"'
bindsym Shift+Print exec --no-startup-id sh -c 'LC_TIME=de_DE.UTF-8 maim --window $(xdotool getactivewindow) "$HOME/Pictures/screenshots/$(date +'%d-%m-%Y_%Hh-%Mm-%Ss').png"'
bindsym Ctrl+Print exec --no-startup-id sh -c 'LC_TIME=de_DE.UTF-8 maim --select "/home/$USER/Pictures/screenshots/screenshot_$(date +'%d-%m-%Y_%Hh-%Mm-%Ss').png"'

## Clipboard Screenshots
bindsym Ctrl+$mod+Print exec --no-startup-id maim | xclip -selection clipboard -t image/png
bindsym Ctrl+Shift+Print exec --no-startup-id maim --window $(xdotool getactivewindow) | xclip -selection clipboard -t image/png
bindsym Print exec --no-startup-id maim --select | xclip -selection clipboard -t image/png


bindsym $mod+Shift+u exec --no-startup-id eject-extdisc.sh &
'';
  };
   # The state version is required and should stay at the version you
   # originally installed.
   home.stateVersion = "24.05";
  };

  home-manager.backupFileExtension = "backup";
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
   programs.gnupg.agent = {
     enable = true;
     enableSSHSupport = true;
   };

  

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];


  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?









 programs.ssh.knownHostsFiles = [
    (pkgs.writeText "custom_known_hosts" ''
      |1|38S5IADWl8VjK+kg0xobckBjymY=|4sdro5oLsyp/BFpXZ48IUUngm5I= ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
      |1|ziSj2yZw0ruiOCIQ7WFgqH+ERYw=|3Y362JD0kSeVvTNUWVeQDtrLqbI= ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      |1|ez2Jn4SoYJmdI2m0twF82ylz47Q=|IeeY4pGnlNat+kTbQzaq7Fvp8us= ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
144.24.191.218 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMte/kGacIKN2tscKff4Yxpz2eAWhbcrPlmqJfbRqjN9
144.24.191.218 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZ5STJ/iUsG9jkQdmOQLrNMIPEzbK66qom8rTsYuyxbCKZKhYyucX1tJbk2Ip4vmzFux/0gpaZLkxq0sZO1142LjUJkb5J469F66mN1PutHyUxHG3ysUJUSTkA/IgcY3psAo9tmLO>
144.24.191.218 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLvzhygCUJnbS9WfgjP/dWr6b0ESgeUcq6zcUrf6/4IY2YqwcuMrvuXUT3pAEQkHEoDt0BwJR+2V7jDybF7+ep

    '')
  ];


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
     wget
     xclip
     xautolock
     i3lock
     xss-lock
     ranger
     betterlockscreen
     git
     fprintd
     usbutils
     feh
     dunst
     alsa-utils
     polybar
     pavucontrol
     brightnessctl
     networkmanager_dmenu
     bc
     arandr
     xidlehook
     libnotify
     python3
     openjdk11
     playerctl
     jq
     yad
     hwinfo
     killall
     pam
     xorg.xmodmap
     maim
     xdotool
     xdg-utils
     cryptsetup
     xorg.setxkbmap
     libimobiledevice #for mounting iphone 
     ifuse   #for mounting iphone
     libheif #for converting iphone pictures
     pciutils
     usbmuxd
     git-crypt
     nodejs_22
     syncthing
     rofi
     qt5Full
     python310Packages.pyqt5
     xbindkeys
     openvpn
    # agenix
     kdePackages.kdialog
     lock-idle
     pamixer
     android-tools
     adb-sync


   (vscode-with-extensions.override {
    vscodeExtensions = with vscode-extensions; [
      ms-python.python
      ];
    })


    (pkgs.writeShellScriptBin "post-install.sh" ''
#!/usr/bin/env bash

# Überprüfen der Internetverbindung
if ! ping -c 1 google.com &> /dev/null; then
    echo "Keine Internetverbindung erkannt."
    read -p "Möchten Sie sich mit einem Netzwerk verbinden? (J/n): " -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ssid=$(kdialog --inputbox "Bitte geben Sie den Netzwerk-Namen (SSID) ein:")
        password=$(kdialog --password "Bitte geben Sie das Netzwerk-Passwort ein:")
        nmcli dev wifi connect "$ssid" password "$password"
    else
        echo "Keine Internetverbindung. Skript wird beendet."
        exit 1
    fi
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie einen Fingerabdruck einrichten? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo fprintd-enroll
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

cd /home/tom/setup

# Überprüfen, ob das Remote-Repository bereits gesetzt wurde
REMOTE_URL=$(git remote get-url origin)
if [ "$REMOTE_URL" != "git@github.com:tombo09/setup.git" ]; then
    git remote set-url origin git@github.com:tombo09/setup.git
    echo "Git remote URL wurde gesetzt."
else
    echo "Git remote URL ist bereits korrekt."
fi

cd /home/tom/

read -p "Möchten Sie das Repository klonen? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Bitte stecken Sie Ihren YubiKey ein."
    while [ $(lsusb | grep -c 'Yubico') -eq 0 ]; do
        echo -ne "Warten auf YubiKey...\r"
        sleep 0.7
        echo -ne "                     \r"
        sleep 0.7
    done
    echo "YubiKey erkannt."
    if git clone git@github.com:tombo09/data.git; then
        echo "Das Repository wurde erfolgreich geklont."
    else
        echo "Das Klonen des Repositories ist fehlgeschlagen."
    fi
fi


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie das Repository entschlüsseln (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Bitte stecken Sie Ihren YubiKey ein."
    while [ $(lsusb | grep -c 'Yubico') -eq 0 ]; do
        echo -ne "Warten auf YubiKey...\r"
        sleep 0.7
        echo -ne "                     \r"
        sleep 0.7
    done
    echo "YubiKey erkannt."
    cd /home/tom/data
    if git-crypt unlock; then
        echo "Das Repository wurde erfolgreich entschlüsselt."
    else
        echo "Die Entschlüsselung des Repositories ist fehlgeschlagen."
    fi
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Symlinks werden eingerichtet."


# Überprüfen und löschen, wenn /etc/nixos/configuration.nix existiert
if [ -e /etc/nixos/configuration.nix ]; then
    sudo rm /etc/nixos/configuration.nix
fi

# Überprüfen und erstellen, wenn der symlink nicht existiert
if [ ! -L /etc/nixos/configuration.nix ]; then
    sudo ln -s /home/tom/setup/configuration.nix /etc/nixos/configuration.nix
    echo "configuration.nix Symlink wurde erfolgreich gesetzt."
fi


# Überprüfen und erstellen, wenn der symlink nicht existiert
if [ ! -L /home/tom/.config/Passwords.kdbx ]; then
    sudo ln -s /home/tom/data/Passwords.kdbx /home/tom/.config/Passwords.kdbx
    echo "Keepassxc Symlink wurde erfolgreich gesetzt."
fi


# polybar-position.py
if [ ! -L /home/tom/.config/polybar-position.py ]; then
    ln -s /home/tom/data/scalp/polybar-position.py /home/tom/.config/polybar-position.py
    echo "polybar-position.py Symlink wurde erfolgreich gesetzt."
fi

# shortcut-execute.sh
if [ ! -L /home/tom/.config/shortcut-execute.sh ]; then
    ln -s /home/tom/data/scalp/shortcut-execute.sh /home/tom/.config/shortcut-execute.sh
    echo "shortcut-execute.sh Symlink wurde erfolgreich gesetzt."
fi

# polybar-positon-exe.sh
if [ ! -L /home/tom/.config/polybar-position-exe.sh ]; then
    ln -s /home/tom/data/scalp/polybar-position-exe.sh /home/tom/.config/polybar-position-exe.sh
    echo "shortcut-execute.sh Symlink wurde erfolgreich gesetzt."
fi



#venv einrichten
python3 -m venv /home/tom/.config/venv
source /home/tom/.config/venv/bin/activate
pip install requests
deactivate

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Abfrage ob die Sitzung wiederhergestellt werden soll
read -p "Letzte Firefox-Sitzung wiederherstellen? (J/n): " -r
echo

# Überprüfen, ob der Benutzer nicht mit 'N' oder 'n' geantwortet hat
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Firefox-Prozess beenden
    pkill -f firefox
    sleep 0.5

    # Sicherstellen, dass das Profilverzeichnis existiert
    mkdir -p /home/tom/.mozilla/firefox/tom.default

    # profiles.ini ins Firefox-Verzeichnis kopieren
    cp /home/tom/data/firefox/settings/profiles.ini /home/tom/.mozilla/firefox/

    # Wichtige Dateien ins Profilverzeichnis kopieren
    cp ~/data/firefox/settings/key4.db ~/.mozilla/firefox/tom.default/key4.db
    cp ~/data/firefox/settings/logins.json ~/.mozilla/firefox/tom.default/logins.json
    cp ~/data/firefox/settings/user.js ~/.mozilla/firefox/tom.default/user.js
    cp ~/data/firefox/settings/places.sqlite ~/.mozilla/firefox/tom.default/places.sqlite
    cp -r ~/data/firefox/settings/extensions/ ~/.mozilla/firefox/tom.default/

    # Sitzung wiederherstellen
    session_file=/home/tom/.mozilla/firefox/tom.default/sessionstore.jsonlz4
    if [ -f /home/tom/data/firefox/session/recovery.jsonlz4 ]; then
        cp /home/tom/data/firefox/session/recovery.jsonlz4 "$session_file"
        sleep 0.5
        
        # Firefox neu starten
        firefox &
	sleep 0.5
	i3-msg reload > /dev/null 2>&1
	i3-msg restart > /dev/null 2>&1
        echo "Letzte Firefox-Sitzung wurde erfolgreich wiederhergestellt."
    else
        echo "Vorherige Sitzung nicht gefunden. Firefox wird nicht wiederhergestellt."
    fi
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie die letzte Obsidian-Sitzung wiederherstellen? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    pkill -f obsidian
    sleep 0.5
    echo '{"vaults":{"ae1d4fd0a33d9f5f":{"path":"/home/tom/data/tom-obsidian","ts":1723243908158,"open":true}}}' > /home/tom/.config/obsidian/obsidian.json
    sleep 0.5
    obsidian > /dev/null 2>&1 &
    echo "Letzte Obsidian-Sitzung wurde erfolgreich wiederhergestellti."
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie die letzte Keepassxc-Sitzung wiederherstellen? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    mkdir -p /home/tom/.cache/keepassxc
    touch /home/tom/.cache/keepassxc/keepassxc.ini
    sed -i '/^LastOpenedDatabases=/c\LastOpenedDatabases=/home/tom/.config/Passwords.kdbx' /home/tom/.cache/keepassxc/keepassxc.ini && grep -q '^LastOpenedDatabases=' /home/tom/.cache/keepassxc/keepassxc.ini || echo 'LastOpenedDatabases=/home/tom/.config/Passwords.kdbx' >> /home/tom/.cache/keepassxc/keepassxc.ini
    sed -i '/^LastDatabases=/c\LastDatabases=/home/tom/.config/Passwords.kdbx' /home/tom/.cache/keepassxc/keepassxc.ini && grep -q '^LastDatabases=' /home/tom/.cache/keepassxc/keepassxc.ini || echo 'LastDatabases=/home/tom/.config/Passwords.kdbx' >> /home/tom/.cache/keepassxc/keepassxc.ini
    sed -i '/^LastActiveDatabase=/c\LastActiveDatabase=/home/tom/.config/Passwords.kdbx' /home/tom/.cache/keepassxc/keepassxc.ini && grep -q '^LastActiveDatabase=' /home/tom/.cache/keepassxc/keepassxc.ini || echo 'LastActiveDatabase=/home/tom/.config/Passwords.kdbx' >> /home/tom/.cache/keepassxc/keepassxc.ini

    echo "Letzte Keepassxc-Sitzung wurde erfolgreich wiederhergestellt."

fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie Hibernation einrichten? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Hibernation wird eingerichtet..."

    # Swap-Datei und Resume-Konfiguration (keine Benutzerabfrage)
    find_largest_partition() {
        largest_partition=""
        largest_size=0
        for partition in $(lsblk -ln -o NAME); do
            if [[ $partition == dm-* ]]; then
                continue
            fi
            size=$(lsblk -ln -o SIZE /dev/$partition | grep -o '[0-9.]*')
            unit=$(lsblk -ln -o SIZE /dev/$partition | grep -o '[A-Z]*')
            case $unit in
                K) size_in_gb=$(echo "$size / 1024 / 1024" | bc -l) ;;
                M) size_in_gb=$(echo "$size / 1024" | bc -l) ;;
                G) size_in_gb=$size ;;
                T) size_in_gb=$(echo "$size * 1024" | bc -l) ;;
                *) size_in_gb=0 ;;
            esac
            if (( $(echo "$size_in_gb > $largest_size" | bc -l) )); then
                largest_size=$size_in_gb
                largest_partition="/dev/$partition"
            fi
        done
        echo "$largest_partition"
    }

    find_encrypted_root_partition() {
        for mapper_partition in $(ls /dev/mapper/*); do
            if [[ $(lsblk -ln -o MOUNTPOINT $mapper_partition) == "/" ]]; then
                echo "$mapper_partition"
                return
            fi
        done
        echo ""
    }

    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if grep -q '/var/swapfile' /proc/swaps; then
        # Swapfile ist aktiv, swapoff ausführen
        sudo swapoff /var/swapfile
    fi
    sudo dd if=/dev/zero of=/var/swapfile bs=1M count=$total_ram
    sudo chmod 600 /var/swapfile
    sudo mkswap /var/swapfile
    sudo swapon /var/swapfile
    offset=$(sudo filefrag -v /var/swapfile | grep " 0:" | awk '{print $4}' | sed 's/\.\.//')
    root_partition=$(find_encrypted_root_partition)
    if [[ -z "$root_partition" ]]; then
        root_partition=$(find_largest_partition)
    fi
    if [[ -z "$root_partition" ]]; then
        echo "Root partition not found."
        exit 1
    fi
    root_uuid=$(sudo blkid -s UUID -o value /var/swapfile)
    config_file="/etc/nixos/hardware-configuration.nix"

    sudo sed -i '/swapDevices = \[ \];/d' $config_file
    if grep -q 'swapDevices = \[.*{.*device = "/var/swapfile";.*size = [0-9]*;.*}.*\];' "$config_file"; then
        sudo sed -i "s|swapDevices = \[.*{.*device = \"/var/swapfile\";.*size = [0-9]*;.*}.*\];|swapDevices = [ { device = \"/var/swapfile\"; size = $total_ram; } ];|g" "$config_file"
    else
        sudo sed -i.bak '/^}$/i\  swapDevices = [ { device = "/var/swapfile"; size = '"$total_ram"'; } ];' "$config_file"
    fi

    if grep -q 'boot.resumeDevice = "/dev/.*";' "$config_file"; then
        sudo sed -i "s|boot.resumeDevice = \"/dev/.*\";|boot.resumeDevice = \"$root_partition\";|g" "$config_file"
    else
        sudo sed -i.bak '/^}$/i\  boot.resumeDevice = "'"$root_partition"'";' "$config_file"
    fi

    if grep -q 'resume=UUID=[a-fA-F0-9-]*' "$config_file"; then
        sudo sed -i "s|resume=UUID=[a-fA-F0-9-]*|resume=UUID=''${root_uuid}|g" "$config_file"
    else
        sudo sed -i.bak '/^}$/i\  boot.kernelParams = [ "resume=UUID='"$root_uuid"'"' "$config_file"
    fi

    if grep -q 'resume_offset=[0-9]*' "$config_file"; then
        sudo sed -i "s|resume_offset=[0-9]*|resume_offset=''${offset}|g" "$config_file"
    else
        sudo sed -i.bak '/^}$/i\  "resume_offset='"$offset"'" ];' "$config_file"
    fi

    echo "Hibernation wurde erfolgreich eingerichtet."
else
    echo "Hibernation wurde nicht eingerichtet."
fi

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


echo "Kernel-Parameter werden eingerichtet..."

config_file="/etc/nixos/hardware-configuration.nix"

# Wichtig für Audio auf manchen Geräten
# Überprüfen, ob ein Intel-Chip vorhanden ist
if lspci | grep -q 'Intel'; then
    echo "Intel-Chip erkannt."

    # Überprüfen, ob der Kernel-Parameter bereits vorhanden ist
    if ! grep -q 'snd-intel-dspcfg.dsp_driver=1' "$config_file"; then
        echo "Kernel-Parameter nicht vorhanden. Füge ihn hinzu."

        # Füge den Kernel-Parameter hinzu, wenn er noch nicht existiert
        # Überprüfe, ob 'boot.kernelParams' existiert, bevor der Parameter hinzugefügt wird
        if grep -q 'boot.kernelParams = \[' "$config_file"; then
            sudo sed -i '/boot.kernelParams = \[/a\    "snd-intel-dspcfg.dsp_driver=1"' "$config_file"
            echo "Kernel-Parameter wurde hinzugefügt."
        else
            echo "Warnung: 'boot.kernelParams' nicht in der Datei gefunden. Parameter konnte nicht hinzugefügt werden."
        fi
    else
        echo "Kernel-Parameter bereits vorhanden. Keine Änderung vorgenommen."
    fi
else
    echo "Kein Intel-Chip erkannt. Keine Änderungen vorgenommen."
fi


#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "System wird aktualisiert..."

sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager
sudo nix-channel --update
sudo nixos-rebuild switch

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

read -p "Möchten Sie das Gerät neu starten, um Hibernate zu aktivieren? (J/n): " -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo reboot
else
    echo "Skript abgeschlossen. Bitte starten Sie das Gerät später neu, um Hibernation zu aktivieren."
fi
    '')

 (pkgs.writeShellScriptBin "backup-home.sh" ''
#!/usr/bin/env bash
lockfile="/tmp/rsync.lock"

if [ -e "$lockfile" ]; then
    echo "rsync läuft bereits."
    exit 1
else
    touch "$lockfile"
    # Führe rsync aus
rsync -av --delete --exclude=".cache" $HOME /run/media/toshiba-2TB/backup/laptop/refreshed/
rsync -av --exclude=".cache" $HOME /run/media/toshiba-2TB/backup/laptop/notrefreshed/
  # Entferne Lock-Datei nach Abschluss
    rm "$lockfile"
fi
  '')
 (pkgs.writeShellScriptBin "check-battery.sh" ''
#!/usr/bin/env bash

# Funktion zur Überprüfung des Batteriestatus
check_battery_status() {
    # Ladezustand der Batterie in Prozent ermitteln
    battery_level=$(cat /sys/class/power_supply/BAT0/capacity)
    battery_status=$(cat /sys/class/power_supply/BAT0/status)
    last_warning_file="/tmp/last_battery_warning"

    # Initialisieren der letzten Warnstufe, falls Datei nicht existiert
    if [ ! -f "$last_warning_file" ]; then
        echo "100" > "$last_warning_file"
    fi

    last_warning_level=$(cat "$last_warning_file")

    # Überprüfen, ob der Ladezustand unter 10% fällt und die Batterie nicht geladen wird
    if [ "$battery_level" -lt 10 ] && [ "$battery_status" != "Charging" ] && [ "$last_warning_level" -ge 10 ]; then
        DISPLAY=:0 notify-send -u critical -t 8000 -i dialog-warning "Battery is below 10% Warning!" "Current level: $battery_level%"
        echo "$battery_level" > "$last_warning_file"
    elif [ "$battery_level" -lt 6 ]; then
        DISPLAY=:0 notify-send -u critical -t 8000 -i dialog-warning "Battery is below 6% Warning!" "Hibernate at 3%! Current level: $battery_level%"
        echo "$battery_level" > "$last_warning_file"
    fi
}

# Hauptfunktion ausführen
check_battery_status

  '')

 (pkgs.writeShellScriptBin "eject-extdisc.sh" ''
#!/usr/bin/env bash
#


# UUID der verschlüsselten Partition
UUID="fa2a1b43-fe24-4213-819f-a3e72d8020b3"  # Ersetzen Sie dies durch die tatsächliche UUID Ihrer verschlüsselten Partition
MAPPER_NAME="toshiba-2TB"
MOUNT_POINT="/run/media/toshiba-2TB"

# Abfrage des sudo-Passworts mit kdialog
SUDO_PASSWORD=$(kdialog --password "Geben Sie Ihr sudo-Passwort ein:")

# Überprüfen, ob ein Passwort eingegeben wurde
if [ -z "$SUDO_PASSWORD" ]; then
    kdialog --error "Es wurde kein Passwort eingegeben. Das Skript wird beendet."
    exit 1
fi

# Finden des Geräts basierend auf der UUID
DEVICE=$(echo "$SUDO_PASSWORD" | sudo -S blkid -o device -t UUID=$UUID)

# Überprüfen, ob das Gerät gefunden wurde
if [ -z "$DEVICE" ]; then
    kdialog --error "Das Gerät mit der UUID $UUID wurde nicht gefunden. Das Skript wird beendet."
    exit 1
fi

# Entmounte das Verzeichnis, falls es gemountet ist
echo "$SUDO_PASSWORD" | sudo -S umount "$MOUNT_POINT"

# Schließe das verschlüsselte Laufwerk
echo "$SUDO_PASSWORD" | sudo -S cryptsetup luksClose "$MAPPER_NAME"

# Schalte das Laufwerk aus
echo "$SUDO_PASSWORD" | sudo -S udisksctl power-off -b "$DEVICE"
'')


(pkgs.writeShellScriptBin "iphone-backup.sh" ''
#!/usr/bin/env bash

lockfile="/tmp/rsync_ifuse.lock"
BASEDIR="/home/tom/Pictures/iphone/"

# Erstelle das Verzeichnis, wenn es nicht existiert
if [ ! -d "$BASEDIR" ]; then
    mkdir -p "$BASEDIR"
fi

# Funktion, um den Ordner /tmp/iphone zu erstellen, ifuse auszuführen und Inhalte zu synchronisieren
create_and_sync_pics_folder() {
    # Erstelle den Ordner und führe ifuse aus, wenn nicht vorhanden
    if [ ! -d "/tmp/iphone" ]; then
       mkdir /tmp/iphone && ifuse /tmp/iphone
    fi
    # Synchronisiere die Bilder
    rsync -av "/tmp/iphone/DCIM/" "$BASEDIR"
}

# Prüfe, ob bereits ein Prozess läuft
if [ -e "$lockfile" ]; then
    echo "Ein anderer Synchronisationsprozess läuft bereits."
    exit 0  # Beendet das Skript sofort
fi

# Erstelle eine Lock-Datei, um zu signalisieren, dass ein Prozess läuft
touch "$lockfile"

# Erstelle den Ordner /tmp/iphone, führe ifuse aus und synchronisiere
create_and_sync_pics_folder

# Entferne die Lock-Datei nach Abschluss
rm -f "$lockfile"

# Füge eine kurze Pause hinzu, um das System nicht zu überlasten (optional)
sleep 5

#-----------------------------------------------------------------------------------------------------------------------------
fusermount -u /tmp/iphone && rmdir /tmp/iphone


# Navigiere durch alle Unterordner und finde HEIC-Dateien zur Konvertierung
find "$BASEDIR" -type f -name "*.HEIC" | while read file; do
    # Extrahiere den Dateinamen ohne Erweiterung
    filename=$(basename "$file" .HEIC)

    # Definiere den Pfad für die Ausgabedatei (gleicher Ordner wie das Original)
    output="''${file%.HEIC}.jpg"

    # Überprüfe, ob die JPG-Version bereits existiert, um unnötige Konvertierungen zu vermeiden
    if [ ! -f "$output" ]; then
        # Konvertiere die HEIC-Datei in eine JPG-Datei mit maximaler Qualität
        heif-convert -q 100 "$file" "$output"

        # Optional: Rückmeldung geben, welche Datei konvertiert wurde
        echo "Konvertiert: $file -> $output"
    else
        echo "Datei existiert bereits und wurde übersprungen: $output"
    fi
done

# Nachdem alle HEIC-Dateien konvertiert wurden, lösche alle verbleibenden HEIC-Dateien
find "$BASEDIR" -type f -name "*.HEIC" -exec rm -f {} \;
echo "Alle HEIC-Dateien wurden gelöscht."
  '')




(pkgs.writeShellScriptBin "phone-backup.sh" ''
#!/usr/bin/env bash
set -euo pipefail

# --- Einstellungen ---
lockfile="/tmp/adb_dcim_sync.lock"
BASEDIR="/home/tom/Pictures/phone/"
CAMDIR="''${BASEDIR%/}/camera/"
OTHDIR="''${BASEDIR%/}/other/"
DEVICE_SERIAL="''${1:-akita}"     # Optional: ADB-Seriennummer als 1. Argument
ADB_BIN="''${ADB_BIN:-adb}"

notify() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Phone Backup" "$msg"
  fi
  echo "$msg" >&2
}

# --- Vor der ersten Suche kurz warten ---
sleep 5

# --- ADB starten ---
$ADB_BIN start-server >/dev/null 2>&1 || true

# --- Bis zu 3 Versuche, Gerät zu finden (mit 5s Pause) ---
attempt=1
max_attempts=3
found=0

while [ "''${attempt}" -le "''${max_attempts}" ]; do
  if $ADB_BIN -s "$DEVICE_SERIAL" get-state >/dev/null 2>&1; then
    found=1
  else
    # Falls das angegebene/Standard-Gerät nicht erreichbar ist:
    mapfile -t devices < <($ADB_BIN devices | awk '/\tdevice$/{print $1}' | tr -d "\r")
    if [ "''${#devices[@]}" -eq 1 ]; then
      DEVICE_SERIAL="''${devices[0]}"
      if $ADB_BIN -s "$DEVICE_SERIAL" get-state >/dev/null 2>&1; then
        found=1
      fi
    fi
  fi

  [ "''${found}" -eq 1 ] && break

  if [ "''${attempt}" -lt "''${max_attempts}" ]; then
    sleep 5
  fi
  attempt=$((attempt+1))
done

state="$($ADB_BIN -s "$DEVICE_SERIAL" get-state 2>/dev/null || true)"
if [ "''${found}" -ne 1 ] || [ "$state" != "device" ]; then
  notify "Kein Phone gefunden – evtl. USB-Debugging aktivieren."
  exit 1
fi

# --- kdialog-Abfrage vor Start ---
notify "Phone gefunden ($DEVICE_SERIAL)."
if command -v kdialog >/dev/null 2>&1; then
  if ! kdialog --yesno "Phone ($DEVICE_SERIAL) erkannt.\nBackup jetzt starten?"; then
    notify "Backup abgebrochen."
    exit 0
  fi
fi
notify "Starte Backup …"

# --- Verzeichnisse anlegen ---
mkdir -p "$CAMDIR" "$OTHDIR"

# --- Lock prüfen ---
if [ -e "$lockfile" ]; then
  echo "Ein anderer Synchronisationsprozess läuft bereits."
  exit 0
fi
touch "$lockfile"
cleanup() { rm -f "$lockfile"; }
trap cleanup EXIT

# --- DCIM prüfen ---
if ! $ADB_BIN -s "$DEVICE_SERIAL" shell 'test -d /sdcard/DCIM'; then
  notify "Auf dem Gerät existiert kein /sdcard/DCIM."
  exit 1
fi

echo "Synchronisiere von $DEVICE_SERIAL:/sdcard/DCIM nach $BASEDIR ..."

# --- Camera-Inhalte nach phone/camera (ohne zusätzliche "Camera"-Ebene) ---
if $ADB_BIN -s "$DEVICE_SERIAL" shell 'test -d /sdcard/DCIM/Camera'; then
  $ADB_BIN -s "$DEVICE_SERIAL" pull -a "/sdcard/DCIM/Camera/." "$CAMDIR"
fi

# --- Alle anderen DCIM-Einträge nach phone/other ---
mapfile -t entries < <($ADB_BIN -s "$DEVICE_SERIAL" shell 'ls -1 /sdcard/DCIM' | tr -d "\r" || true)
for name in "''${entries[@]}"; do
  [ -z "$name" ] && continue
  [ "$name" = "Camera" ] && continue
  $ADB_BIN -s "$DEVICE_SERIAL" pull -a "/sdcard/DCIM/$name" "$OTHDIR"
done

notify "Backup abgeschlossen."
# Kurze Pause wie im Original (optional)
sleep 5
'')


(pkgs.writeShellScriptBin "setup-monitor.sh" ''
#!/usr/bin/env bash

# Liste der erlaubten Geräteseriennummern
ALLOWED_DEVICE_SERIALS=("34Q8W13" "0" "serial-ID-3" "")

# Interner Monitor
IN="eDP-1"
# Externer Monitor
EXT="DP-2"
USE_MONITOR=''${1:-no-monitor}
POSITION=''${2:-left-of}
MODE=''${3:-extend}

# Funktion, um die Seriennummern der Monitore zu erhalten
get_monitor_serials() {
    hwinfo --monitor | grep "Serial ID:" | awk -F ': ' '{print $2}'
}

# Funktion, um die Polybar zu starten
start_polybar() {
    killall -q polybar
    while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
    polybar bar &
}

# Polybar initial stoppen
killall -q polybar

if [ "$USE_MONITOR" == "monitor" ]; then
    # Überprüfen, ob der externe Monitor angeschlossen ist
    if xrandr --query | grep -q "$EXT connected"; then
        # Alle Seriennummern der angeschlossenen Monitore abrufen
        MONITOR_SERIALS=$(get_monitor_serials)

        # Debugging: Seriennummern ausgeben
        echo "Erkannte Seriennummern der Monitore:"
        echo "$MONITOR_SERIALS"

        # Variable zum Verfolgen, ob alle Monitore erlaubt sind
        ALL_ALLOWED=true

        # Überprüfen, ob jede erkannte Seriennummer in der Liste der erlaubten Seriennummern ist
        for serial in $MONITOR_SERIALS; do
            serial=$(echo "$serial" | xargs)  # Entfernt führende und nachfolgende Leerzeichen
            ALLOWED=false
            for allowed_serial in "''${ALLOWED_DEVICE_SERIALS[@]}"; do
                if [[ "$serial" == "$allowed_serial" ]]; then
                    ALLOWED=true
                    break
                fi
            done

            if [[ "$ALLOWED" == false ]]; then
                echo "Seriennummer $serial ist nicht erlaubt."
                if ! yad --question --text="Möchten Sie den Monitor mit der Seriennummer $serial verwenden?"; then
                    echo "Benutzer hat die Verwendung des Monitors mit der Seriennummer $serial abgelehnt"
                    exit 1
                else
                    echo "Benutzer hat die Verwendung des Monitors mit der Seriennummer $serial akzeptiert"
                    # Wenn der Benutzer die Verwendung akzeptiert, setzen wir ALLOWED auf true
                    ALLOWED=true
                fi
            else
                echo "Seriennummer $serial ist erlaubt."
            fi

            # Wenn der Benutzer die Verwendung eines fremden Monitors akzeptiert hat, brechen wir die Schleife ab
            if [[ "$ALLOWED" == true ]]; then
                break
            fi
        done

        # Externer Monitor ist erlaubt oder Benutzer hat ihn akzeptiert
        if [ "$MODE" == "mirror" ]; then
            # Monitore spiegeln
            xrandr --output $IN --auto --output $EXT --auto --same-as $IN --primary
            # Polybar neu starten
            start_polybar
        else
            # Monitore erweitern und gemäß der angegebenen Position ausrichten
            xrandr --output $IN --auto --output $EXT --auto --$POSITION $IN --primary

            # Alle Arbeitsbereiche auf den externen Monitor verschieben
            for workspace in $(i3-msg -t get_workspaces | jq -r '.[].name'); do
                i3-msg workspace "$workspace"
                i3-msg move workspace to output $EXT
            done

            # i3-Konfiguration neu laden
            i3-msg restart
        fi
    else
        echo "Externer Monitor ist nicht angeschlossen."
        # Polybar neu starten
        start_polybar
    fi
else
    # Externer Monitor soll nicht verwendet werden
    xrandr --output $IN --auto --output $EXT --off

    # Alle Arbeitsbereiche zurück auf den internen Monitor verschieben
    for workspace in $(i3-msg -t get_workspaces | jq -r '.[].name'); do
        i3-msg workspace "$workspace"
        i3-msg move workspace to output $IN
    done

    # i3-Konfiguration neu laden
    i3-msg restart
fi
  '')

(pkgs.writeShellScriptBin "clean-generations.sh" ''
#!/usr/bin/env bash
set -euo pipefail

## Defaults
keepGensDef=10; keepDaysDef=20
keepGens=$keepGensDef; keepDays=$keepDaysDef

## Usage
usage () {
    printf "Usage:\n\t ./trim-generations.sh <keep-gernerations> <keep-days> <profile> \n\n
(defaults are: Keep-Gens=$keepGensDef Keep-Days=$keepDaysDef Profile=user)\n\n"
    printf "If you enter any parameters, you must enter all three, or none to use defaults.\n"
    printf "Example:\n\t trim-generations.sh 15 10 home-manager\n"
    printf "  this will work on the home-manager profile and keep all generations from the\n"
    printf "last 10 days, and keep at least 15 generations no matter how old.\n"
    printf "\nProfiles available are:\tuser, home-manager, channels, system (root)\n"
    printf "\n-h or --help prints this help text."
}

if [ $# -eq 1 ]; then      # if help requested
    if [ $1 = "-h" ]; then
         usage
         exit 1;
    fi
    if [ $1 = "--help" ]; then
         usage
         exit 2;
    fi
    printf "Dont recognise your option exiting..\n\n"
    usage
    exit 3;

    elif [ $# -eq 0 ]; then            # print the defaults
        printf "The current defaults are:\n Keep-Gens=$keepGensDef Keep-Days=$keepDaysDef \n\n"
        read -p "Keep these defaults? (y/n):" answer

        case "$answer" in
        [yY1] )
                printf "Using defaults..\n"
            ;;
        [nN0] ) printf "ok, doing nothing, exiting..\n"
            exit 6;
            ;;
        *     ) printf "%b" "Doing nothing, exiting.."
            exit 7;
            ;;
        esac
fi

## Handle parameters (and change if root)
if [[ $EUID -ne 0 ]]; then              # if not root
    profile=$(readlink /home/$USER/.nix-profile)
else
    if [ -d /nix/var/nix/profiles/system ]; then   # maybe this or the other
        profile="/nix/var/nix/profiles/system"
    elif [ -d /nix/var/nix/profiles/default ]; then
        profile="/nix/var/nix/profiles/default"
    else
        echo "Cant find profile for root. Exiting"
        exit 8
    fi
fi
if (( $# < 1 )); then
    printf "Keeping default: $keepGensDef generations OR $keepDaysDef days, whichever is more\n"
elif [[ $# -le 2 ]]; then
    printf "\nError: Not enough arguments.\n\n" >&2
    usage
    exit 1
elif (( $# > 4)); then
    printf "\nError: Too many arguments.\n\n" >&2
    usage
    exit 2
else
    if [ $1 -lt 1 ]; then
        printf "using Gen numbers less than 1 not recommended. Setting to min=1\n"
        read -p "is that ok? (y/n): " asnwer
        #printf "$asnwer"
        case "$asnwer" in
        [yY1] )
            printf "ok, continuing..\n"
            ;;
        [nN0] )
            printf "ok, doing nothing, exiting..\n"
            exit 6;
            ;;
        *     )
            printf "%b" "Doing nothing, exiting.."
            exit 7;
            ;;
        esac
    fi
    if [ $2 -lt 0 ]; then
        printf "using negative days number not recommended. Setting to min=0\n"
        read -p "is that ok? (y/n): " asnwer

        case "$asnwer" in
        [yY1] )
            printf "ok, continuing..\n"
            ;;
        [nN0] )
            printf "ok, doing nothing, exiting..\n"
            exit 6;
            ;;
        *     )
            printf "%b" "Doing nothing, exiting.."
            exit 7;
            ;;
        esac
    fi
    keepGens=$1; keepDays=$2;
    (( keepGens < 1 )) && keepGens=1
    (( keepDays < 0 )) && keepDays=0
    if [[ $EUID -ne 0 ]]; then
        if [[ $3 == "user" ]] || [[ $3 == "default" ]]; then
            profile=$(readlink /home/$USER/.nix-profile)
        elif [[ $3 == "home-manager" ]]; then
            # home-manager defaults to $XDG_STATE_HOME; otherwise, use
            # `home-manager generations` and `nix-store --query --roots
            # /nix/store/...` to figure out what reference is keeping the old
            # generations alive.
            profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
        elif [[ $3 == "channels" ]]; then
            profile="/nix/var/nix/profiles/per-user/$USER/channels"
        else
            printf "\nError: Do not understand your third argument. Should be one of: (user / home-manager/ channels)\n\n"
            usage
            exit 3
        fi
    else
        if [[ $3 == "system" ]]; then
            profile="/nix/var/nix/profiles/system"
        elif [[ $3 == "user" ]] || [[ $3 == "default" ]]; then
            profile="/nix/var/nix/profiles/default"
        else
            printf "\nError: Do not understand your third argument. Should be one of: (user / system)\n\n"
            usage
            exit 3
        fi
    fi
    printf "OK! \t Keep Gens = $keepGens \t Keep Days = $keepDays\n\n"
fi

printf "Operating on profile: \t $profile\n\n"

## Runs at the end, to decide whether to delete profiles that match chosen parameters.
choose () {
    local default="$1"
    local prompt="$2"
    local answer

    read -p "$prompt" answer
    [ -z "$answer" ] && answer="$default"

    case "$answer" in
        [yY1] ) #printf "answered yes!\n"
             nix-env --delete-generations -p $profile ''${!gens[@]}
            exit 0
            ;;
        [nN0] ) printf "Ok doing nothing exiting..\n"
            exit 6;
            ;;
        *     ) printf "%b" "Unexpected answer '$answer'!" >&2
            exit 7;
            ;;
    esac
} # end of function choose

# printf "profile = $profile\n\n"
## Query nix-env for generations list
IFS=$'\n' nixGens=( $(nix-env --list-generations -p $profile | sed 's:^\s*::; s:\s*$::' | tr '\t' ' ' | tr -s ' ') )
timeNow=$(date +%s)

## Get info on oldest generation
IFS=' ' read -r -a oldestGenArr <<< "''${nixGens[0]}"
oldestGen=''${oldestGenArr[0]}
oldestDate=''${oldestGenArr[1]}
printf "%-30s %s\n" "oldest generation:" $oldestGen
#oldestDate=''${nixGens[0]:3:19}
printf "%-30s %s\n" "oldest generation created:" $oldestDate
oldestTime=$(date -d "$oldestDate" +%s)
oldestElapsedSecs=$((timeNow-oldestTime))
oldestElapsedMins=$((oldestElapsedSecs/60))
oldestElapsedHours=$((oldestElapsedMins/60))
oldestElapsedDays=$((oldestElapsedHours/24))
printf "%-30s %s\n" "minutes before now:" $oldestElapsedMins
printf "%-30s %s\n" "hours before now:" $oldestElapsedHours
printf "%-30s %s\n\n" "days before now:" $oldestElapsedDays

## Get info on current generation
for i in "''${nixGens[@]}"; do
    IFS=' ' read -r -a iGenArr <<< "$i"
    genNumber=''${iGenArr[0]}
    genDate=''${iGenArr[1]}
    if [[ "$i" =~ current ]]; then
        currentGen=$genNumber
        printf "%-30s %s\n" "current generation:" $currentGen
        currentDate=$genDate
        printf "%-30s %s\n" "current generation created:" $currentDate
        currentTime=$(date -d "$currentDate" +%s)
        currentElapsedSecs=$((timeNow-currentTime))
        currentElapsedMins=$((currentElapsedSecs/60))
        currentElapsedHours=$((currentElapsedMins/60))
        currentElapsedDays=$((currentElapsedHours/24))
        printf "%-30s %s\n" "minutes before now:" $currentElapsedMins
        printf "%-30s %s\n" "hours before now:" $currentElapsedHours
        printf "%-30s %s\n\n" "days before now:" $currentElapsedDays
    fi
done

## Compare oldest and current generations
timeBetweenOldestAndCurrent=$((currentTime-oldestTime))
elapsedDays=$((timeBetweenOldestAndCurrent/60/60/24))
generationsDiff=$((currentGen-oldestGen))

## Figure out what we should do, based on generations and options
if [[ elapsedDays -le keepDays ]]; then
    printf "All generations are no more than $keepDays days older than current generation. \nOldest gen days difference from current gen: $elapsedDays \n\n\tNothing to do!\n"
    exit 4;
elif [[ generationsDiff -lt keepGens ]]; then
    printf "Oldest generation ($oldestGen) is only $generationsDiff generations behind current ($currentGen). \n\n\t Nothing to do!\n"
    exit 5;
else
    printf "\tSomething to do...\n"
    declare -a gens
    for i in "''${nixGens[@]}"; do
        IFS=' ' read -r -a iGenArr <<< "$i"
        genNumber=''${iGenArr[0]}
        genDiff=$((currentGen-genNumber))
        genDate=''${iGenArr[1]}
        genTime=$(date -d "$genDate" +%s)
        elapsedSecs=$((timeNow-genTime))
        genDaysOld=$((elapsedSecs/60/60/24))
        if [[ genDaysOld -gt keepDays ]] && [[ genDiff -ge keepGens ]]; then
            gens["$genNumber"]="$genDate, $genDaysOld day(s) old"
        fi
    done
    printf "\nFound the following generation(s) to delete:\n"
    for K in "''${!gens[@]}"; do
        printf "generation $K \t ''${gens[$K]}\n"
    done
    printf "\n"
    choose "y" "Do you want to delete these? [Y/n]: "
fi
  '')
(pkgs.writeShellScriptBin "setup-hibernation.sh" ''
#!/usr/bin/env bash

# Swap-Datei und Resume-Konfiguration (keine Benutzerabfrage)
find_largest_partition() {
    largest_partition=""
    largest_size=0
    for partition in $(lsblk -ln -o NAME); do
        if [[ $partition == dm-* ]]; then
            continue
        fi
        size=$(lsblk -ln -o SIZE /dev/$partition | grep -o '[0-9.]*')
        unit=$(lsblk -ln -o SIZE /dev/$partition | grep -o '[A-Z]*')
        case $unit in
            K) size_in_gb=$(echo "$size / 1024 / 1024" | bc -l) ;;
            M) size_in_gb=$(echo "$size / 1024" | bc -l) ;;
            G) size_in_gb=$size ;;
            T) size_in_gb=$(echo "$size * 1024" | bc -l) ;;
            *) size_in_gb=0 ;;
        esac
        if (( $(echo "$size_in_gb > $largest_size" | bc -l) )); then
            largest_size=$size_in_gb
            largest_partition="/dev/$partition"
        fi
    done
    echo "$largest_partition"
}

find_encrypted_root_partition() {
    for mapper_partition in $(ls /dev/mapper/*); do
        if [[ $(lsblk -ln -o MOUNTPOINT $mapper_partition) == "/" ]]; then
            echo "$mapper_partition"
            return
        fi
    done
    echo ""
}

total_ram=$(free -m | awk '/^Mem:/{print $2}')
if grep -q '/var/swapfile' /proc/swaps; then
    # Swapfile ist aktiv, swapoff ausführen
    sudo swapoff /var/swapfile
fi
sudo dd if=/dev/zero of=/var/swapfile bs=1M count=$total_ram
sudo chmod 600 /var/swapfile
sudo mkswap /var/swapfile
sudo swapon /var/swapfile
offset=$(sudo filefrag -v /var/swapfile | grep " 0:" | awk '{print $4}' | sed 's/\.\.//')
root_partition=$(find_encrypted_root_partition)
if [[ -z "$root_partition" ]]; then
    root_partition=$(find_largest_partition)
fi
if [[ -z "$root_partition" ]]; then
    echo "Root partition not found."
    exit 1
fi
root_uuid=$(sudo blkid -s UUID -o value $root_partition)
config_file="/etc/nixos/hardware-configuration.nix"

sudo sed -i '/swapDevices = \[ \];/d' $config_file
if grep -q 'swapDevices = \[.*{.*device = "/var/swapfile";.*size = [0-9]*;.*}.*\];' "$config_file"; then
    sudo sed -i "s|swapDevices = \[.*{.*device = \"/var/swapfile\";.*size = [0-9]*;.*}.*\];|swapDevices = [ { device = \"/var/swapfile\"; size = $total_ram; } ];|g" "$config_file"
else
    sudo sed -i.bak '/^}$/i\  swapDevices = [ { device = "/var/swapfile"; size = '"$total_ram"'; } ];' "$config_file"
fi

if grep -q 'boot.resumeDevice = "/dev/.*";' "$config_file"; then
    sudo sed -i "s|boot.resumeDevice = \"/dev/.*\";|boot.resumeDevice = \"$root_partition\";|g" "$config_file"
else
    sudo sed -i.bak '/^}$/i\  boot.resumeDevice = "'"$root_partition"'";' "$config_file"
fi

if grep -q 'resume=UUID=[a-fA-F0-9-]*' "$config_file"; then
    sudo sed -i "s|resume=UUID=[a-fA-F0-9-]*|resume=UUID=''${root_uuid}|g" "$config_file"
else
    sudo sed -i.bak '/^}$/i\  boot.kernelParams = [ "resume=UUID='"$root_uuid"'" ];' "$config_file"
fi

if grep -q 'resume_offset=[0-9]*' "$config_file"; then
    sudo sed -i "s|resume_offset=[0-9]*|resume_offset=''${offset}|g" "$config_file"
else
    sudo sed -i.bak '/^}$/i\  "resume_offset='"$offset"'" ];' "$config_file"
fi
  '')
(pkgs.writeShellScriptBin "launch-polybar.sh" ''
#!/usr/bin/env bash
# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 and bar2
#echo "---" | tee -a /tmp/polybar.log /tmp/polybar.log
#polybar bar 2>&1 | tee -a /tmp/polybar.log & disown

#echo "Bars launched..."

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload bar &
  done
else
  polybar --reload bar &
fi
 '')

/*
(pkgs.writeShellScriptBin "shortcut-execute.sh" ''
#!/usr/bin/env bash

set -e

# Funktion: Anzeige der Usage
usage() {
  cat <<EOF
Usage: $0 -a <action> [-l <leverage>] (-m <amount|All> | -g <margin|All>) -e <executionType>

  -a  Aktion (z.B. openLong, closeShort)
  -l  Hebel (z.B. 11) nur erforderlich bei open-Aktionen
  -m  Menge in BTC (z.B. 0.001 oder All)
  -g  Margin in USDT (z.B. 20 oder All)
  -e  Ausführungstyp (z.B. limit_loop, market)

Bei closeLong/closeShort ist -l optional. Du musst genau eines von -m oder -g angeben; als Wert kann auch "All" stehen.
EOF
  exit 1
}

# Parameter einlesen
action=""
leverage=""
amount=""
margin=""
exec_type=""
while getopts "a:l:m:g:e:" opt; do
  case "$opt" in
    a) ACTION="$OPTARG" ;; 
    l) LEVERAGE="$OPTARG" ;; 
    m) AMOUNT="$OPTARG" ;; 
    g) MARGIN="$OPTARG" ;; 
    e) EXEC_TYPE="$OPTARG" ;; 
    *) usage ;; 
  esac
done

# Pflicht-Checks
# 1) Aktion und ExecutionType müssen gesetzt sein
if [ -z "$ACTION" ] || [ -z "$EXEC_TYPE" ]; then
  usage
fi
# 2) Genau eines von amount/margin
if { [ -n "$AMOUNT" ] && [ -n "$MARGIN" ]; } || { [ -z "$AMOUNT" ] && [ -z "$MARGIN" ]; }; then
  usage
fi
# 3) Leverage nur bei non-close-Aktionen erforderlich
if ! [[ "$ACTION" =~ ^close(Long|Short)$ ]] && [ -z "$LEVERAGE" ]; then
  usage
fi

# Fixed values
PASSPHRASE="DmwjmMjLbkRo6Uz9wntqYvIYcLu"
TICKER="BTCUSD"
URL="https://tombo09.com/webhook/strategysix"

# JSON-Body dynamisch aufbauen
BODY="{\"passphrase\":\"''${PASSPHRASE}\",\"ticker\":\"''${TICKER}\",\"action\":\"''${ACTION}\""

# Leverage nur mitschicken, falls gesetzt
if [ -n "$LEVERAGE" ]; then
  BODY+=",\"leverage\":''${LEVERAGE}"
fi

# amount oder margin
if [ -n "$AMOUNT" ]; then
  if [ "$AMOUNT" = "All" ]; then
    BODY+=",\"amount\":\"All\""
  else
    BODY+=",\"amount\":''${AMOUNT}"
  fi
else
  if [ "$MARGIN" = "All" ]; then
    BODY+=",\"margin\":\"All\""
  else
    BODY+=",\"margin\":''${MARGIN}"
  fi
fi

# ExecutionType
BODY+=",\"executionType\":\"''${EXEC_TYPE}\"}"

# Curl ausführen
curl -X POST "$URL" \
     -H "Content-Type: application/json" \
     -d "$BODY"

'')
*/


(pkgs.writeShellScriptBin "update-system.sh" ''
#!/usr/bin/env bash
# Datum des letzten Ausführens: 15.08.2024

# Pfad zur Batteriekapazität
bat_capacity_path="/sys/class/power_supply/BAT0/capacity"

# Überprüft, ob der Pfad existiert
if [ ! -f "$bat_capacity_path" ]; then
  echo -e "\033[0;31mError: Batteriekapazität konnte nicht gefunden werden.\033[0m"
  exit 1
fi

# Liest die Batteriekapazität aus
bat_capacity=$(cat "$bat_capacity_path")

# Überprüft die Batteriekapazität
if [[ $bat_capacity -le 12 ]]; then
  echo -e "\033[0;31mBattery capacity too low!\033[0m"
  exit 1
fi
# Wenn die Batteriekapazität ausreichend ist, wird nichts ausgegeben und das Skript endet normal.

#---------------------------------------------------------------------------------------

# Schwellenwert für RAM-Nutzung in Prozent
threshold=80

# Aktuelle RAM-Nutzung in Prozent ermitteln
ram_usage=$(free | awk '/^Mem:/ {printf("%.0f"), $3/$2 * 100.0}')

# Überprüfen, ob die RAM-Nutzung den Schwellenwert überschreitet
if [ "$ram_usage" -gt "$threshold" ]; then
  echo -e "\033[0;31mRAM usage too high! Currently using $ram_usage% of RAM.\033[0m"
  exit 1
fi
# Wenn die RAM-Nutzung unter dem Schwellenwert liegt, wird nichts ausgegeben und das Skript endet normal.

#-----------------------------------------------------------------------------------------

# Aktuelles Datum und Uhrzeit anzeigen
echo "Aktuelles Datum und Uhrzeit: $(date +"%d.%m.%Y %H:%M")"

# Pfad zur Datei selbst
DATEI=$(realpath "$0")

# Überprüfe, ob die Datei existiert, um das Datum des letzten Ausführens zu lesen
if [ -f "$DATEI" ]; then
  letztesDatum=$(sed -n '2p' "$DATEI" | grep -oP '\d{2}\.\d{2}\.\d{4}')

  if [ -n "$letztesDatum" ]; then
    formatiertesDatum=$(echo $letztesDatum | awk -F"." '{printf "%04d-%02d-%02d", $3, $2, $1}')
    sekLetztesDatum=$(date -d "$formatiertesDatum" +%s)
    sekHeute=$(date +%s)
    diffTage=$(( (sekHeute - sekLetztesDatum) / 86400 ))
    echo "Das Skript wurde zuletzt vor $diffTage Tagen am $letztesDatum ausgeführt."
  else
    echo "Das Skript wird zum ersten Mal ausgeführt."
  fi
else
  echo "Fehler: Die Datei konnte nicht gefunden werden."
  exit 1
fi

# Neues Datum
newDate=$(date "+%d.%m.%Y")

# Aktualisiere das Datum des letzten Ausführens in der Datei
sed -i "2s/.*/# Datum des letzten Ausführens: $newDate/" "$DATEI"

#------------------------------------------------------------------------------------------

# Bash Historie aufräumen
echo -ne "\e[1;34m>>\e[0m Möchtest du die Bash-Historie reinigen? (Y/n): "
read clean_decision
clean_decision=''${clean_decision:-y}

if [[ $clean_decision =~ ^[Yy]$ ]]; then
  password=$(kdialog --password "Enter the keyword, that should be removed from history")
  if [[ -z "$password" ]] || type "$password" &>/dev/null; then
    echo "The input cannot be empty or a valid command."
  else
    temp_file=$(mktemp)
    removed=$(grep -- "$password" ~/.bash_history)

    if [[ ! "$removed" =~ [^[:space:]] ]]; then
      echo "No line with your keyword!"
    else
      echo "Removed the following lines containing your keyword: "
      echo "$removed"
      echo -ne "\e[1;34m>>\e[0m Do you want to remove these commands from your history? (y/N): "
      read remove_decision
      remove_decision=''${remove_decision:-y}

      if [[ $remove_decision =~ ^[Yy]$ ]]; then
        grep -v -- "$password" ~/.bash_history > "$temp_file"
        mv "$temp_file" ~/.bash_history
        echo "Commands have been removed."
      else
        echo "Commands have not been removed."
      fi
    fi

    [[ -f $temp_file ]] && rm "$temp_file"
  fi

  # Laden der .bashrc, um sicherzustellen, dass Aliase verfügbar sind
  if [ -f ~/.bashrc ]; then
    source ~/.bashrc
  fi

  histfile="$HOME/.bash_history"
  tmpfile_dup=$(mktemp)

  awk '!seen[$0]++' "$histfile" > "$tmpfile_dup"
  mv "$tmpfile_dup" "$histfile"
  echo "Duplicates removed."

  check_command() {
    type "$1" &>/dev/null
  }

  temp_file=$(mktemp)
  removed_commands=$(mktemp)

  commands_before=$(wc -l < "$histfile")

  while IFS= read -r command; do
    if [[ ! $command =~ ^[[:space:]]*$ ]]; then
      cmd=$(echo $command | cut -d ' ' -f1)

      if [[ $cmd == "sudo" ]]; then
        cmd=$(echo $command | cut -d ' ' -f2)
      fi

      if check_command "$cmd"; then
        echo "$command" >> "$temp_file"
      else
        echo "$command" >> "$removed_commands"
      fi
    fi
  done < "$histfile"

  if [[ -s $removed_commands ]]; then
    echo -ne "\e[1;34m>>\e[0m Möchtest du die Befehle sehen, die entfernt werden würden? (y/N): "
    read show_decision
    show_decision=''${show_decision:-n}

    if [[ $show_decision == "y" ]]; then
      echo "Entfernte Befehle:"
      cat "$removed_commands"
    fi

    echo -ne "\e[1;34m>>\e[0m Möchtest du diese Befehle wirklich entfernen? (Y/n): "
    read remove_decision
    remove_decision=''${remove_decision:-y}

    if [[ $remove_decision =~ ^[Yy]$ ]]; then
      mv "$temp_file" "$histfile"
      echo "Befehle wurden entfernt."
    else
      echo "Befehle wurden NICHT entfernt."
      rm "$temp_file"
    fi
  else
    echo "Historie hat keine Befehle mit Syntaxfehlern"
  fi

  commands_after=$(wc -l < "$histfile")

  if [ "$commands_before" -ne "$commands_after" ]; then
    echo "Anzahl der Befehle in der Historie von $commands_before Befehlen auf $commands_after reduziert."
  else
    echo "Es wurden keine Befehle entfernt, die Anzahl der Befehle in der history ist immer noch $commands_before."
  fi

  rm "$removed_commands"
fi

#------------------------------------------------------------------

# Funktion zur Überprüfung der Internetverbindung
check_internet() {
  wget -q --spider http://google.com
  return $?
}

# Den Benutzer fragen, ob das System aktualisiert werden soll
echo -ne "\e[1;34m>>\e[0m Möchtest du das System jetzt aktualisieren? (Y/n): "
read update_answer
update_answer=''${update_answer:-y}

if [[ $update_answer =~ ^[Yy]$ ]]; then
  echo "System wird aktualisiert..."

  if check_internet; then
    echo "Internetverbindung erkannt. Aktualisierung wird gestartet..."

    sudo nix-channel --update 
    sudo nixos-rebuild switch --upgrade  
  else
    echo "Keine Internetverbindung erkannt. Systemaktualisierung übersprungen."
  fi
fi

#------------------------------------------------------------------------------------------------------------------------------------


# Frage, ob gereinigt werden soll
printf "\e[1;34m>>\e[0m Möchtest du die System-Generations-Reinigung durchführen? (Y/n): "
read -r clean_generations
clean_generations="''${clean_generations:-y}"

run_cleanup() {
  # KEIN set -e hier – wir wollen nach der Funktion weiterlaufen.

  # Defaults (wie in deinem Lauf): 3 Generationen, 0 Tage
  readonly keepGensDef=12
  readonly keepDaysDef=14
  keepGens=$keepGensDef
  keepDays=$keepDaysDef

  usage() {
    cat <<'EOF'
Usage:
  ./trim-generations.sh <keep-generations> <keep-days> <profile>

(defaults: Keep-Gens=3 Keep-Days=0 Profile=auto)

If you enter any parameters, you must enter all three, or none to use defaults.
Example:
  trim-generations.sh 15 10 home-manager
  -> works on the home-manager profile and keeps all generations from the last 10 days,
     and keeps at least 15 generations no matter how old.

Profiles: user, home-manager, channels, system
EOF
  }

  # ----------------- Hilfsfunktionen -----------------

  # Profil ist systemweit?
  is_system_profile() {
    [[ "$profile" == "/nix/var/nix/profiles/system" || "$profile" == "/nix/var/nix/profiles/default" ]]
  }

  # Root-Runner: führt Befehl als Root aus (sudo, falls nötig)
  run_root() {
    if (( EUID == 0 )); then
      "$@"
    elif command -v sudo >/dev/null 2>&1; then
      sudo -- "$@"
    else
      echo "Benötige Root für: $* (kein sudo gefunden)" >&2
      return 126
    fi
  }

  # Sudo-Credential vorab holen (FIX: korrekt 'sudo -v', NICHT über run_root)
  ensure_sudo() {
    if (( EUID == 0 )); then return 0; fi
    if ! command -v sudo >/dev/null 2>&1; then
      echo "sudo nicht verfügbar – System-Generationen können nicht geprüft/gelöscht werden." >&2
      return 1
    fi
    echo "Zur Prüfung/Löschung von System-Generationen werden Root-Rechte benötigt."
    sudo -v   # <--- FIX: richtige Passwortabfrage
  }

  # Boot-Menü aktualisieren (nur fürs System-Profil)
  refresh_boot_entries() {
    is_system_profile || return 0
    run_root /run/current-system/bin/switch-to-configuration boot \
      || run_root nixos-rebuild boot \
      || run_root nixos-rebuild switch \
      || true
  }

  # GC: systemweit fürs System-Profil, sonst user-GC
  run_gc() {
    if is_system_profile; then
      if command -v nix >/dev/null 2>&1; then
        run_root nix store gc || true
      else
        run_root nix-collect-garbage -d || true
      fi
    else
      if command -v nix >/dev/null 2>&1; then
        nix store gc || true
      else
        nix-collect-garbage -d || true
      fi
    fi
  }

  # Generationsliste des aktuellen $profile
  list_generations() {
    if is_system_profile; then
      run_root nix-env --list-generations -p "$profile"
    else
      nix-env --list-generations -p "$profile"
    fi
  }

  # Automatische Profilwahl (System zuerst, wenn gewünscht; dann HM/User)
  auto_pick_profile() {
    local include_system="$1" p

    if (( EUID == 0 )); then
      # Root: System zuerst, danach ggf. User-ähnliche Profile
      for p in \
        "/nix/var/nix/profiles/system" \
        "/nix/var/nix/profiles/default" \
        "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager" \
        "$HOME/.nix-profile" \
        "/nix/var/nix/profiles/per-user/$USER/channels"
      do
        if nix-env --list-generations -p "$p" >/dev/null 2>&1 \
           && [[ -n $(nix-env --list-generations -p "$p") ]]; then
          profile="$p"; return 0
        fi
      done
    else
      # User: Wenn System eingeschlossen werden soll -> System zuerst via sudo
      if [[ "$include_system" =~ ^[Yy]$ ]]; then
        if ensure_sudo; then
          for p in \
            "/nix/var/nix/profiles/system" \
            "/nix/var/nix/profiles/default"
          do
            if run_root nix-env --list-generations -p "$p" >/dev/null 2>&1 \
               && [[ -n $(run_root nix-env --list-generations -p "$p") ]]; then
              profile="$p"; return 0
            fi
          done
        fi
      fi
      # Danach (oder wenn include_system != Y): HM -> User -> Channels
      for p in \
        "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager" \
        "$HOME/.nix-profile" \
        "/nix/var/nix/profiles/per-user/$USER/channels"
      do
        if nix-env --list-generations -p "$p" >/dev/null 2>&1 \
           && [[ -n $(nix-env --list-generations -p "$p") ]]; then
          profile="$p"; return 0
        fi
      done
    fi

    return 1
  }

  # ----------------- Interaktiv/Args -----------------

  # Optional: System-Generationen berücksichtigen?
  include_sys="y"
  if (( EUID != 0 )); then
    printf "\e[1;34m>>\e[0m Sollen auch System-Generationen geprüft/gelöscht werden? (Y/n): "
    read -r include_sys
    include_sys="''${include_sys:-y}"
  fi

  # Args (0, 3 oder --help)
  if (( $# == 1 )); then
    case "$1" in
      -h|--help) usage; return 0 ;;
      *) printf "Unbekannte Option.\n\n"; usage; return 3 ;;
    esac
  elif (( $# == 0 )); then
    printf "Die aktuellen Defaults sind:\n  Keep-Gens=%s  Keep-Days=%s\n\n" "$keepGensDef" "$keepDaysDef"
    read -r -p "Defaults beibehalten? (y/n): " answer
    case "$answer" in
      [yY1]|"") printf "Verwende Defaults …\n" ;;
      [nN0])    printf "Ok, breche ab …\n"; return 6 ;;
      *)        printf "Eingabe nicht verstanden. Abbruch.\n"; return 7 ;;
    esac
  fi

  # Vorbelegung, wird evtl. von auto_pick überschrieben
  if (( EUID != 0 )); then
    profile="$HOME/.nix-profile"
  else
    if   [ -d /nix/var/nix/profiles/system ]; then
      profile="/nix/var/nix/profiles/system"
    elif [ -d /nix/var/nix/profiles/default ]; then
      profile="/nix/var/nix/profiles/default"
    else
      echo "Konnte Root-Profil nicht finden. Abbruch."
      return 8
    fi
  fi

  # Parameter prüfen/setzen
  if (( $# < 1 )); then
    printf "Behalte Standard: mind. %s Generation(en) ODER %s Tage, je nachdem was mehr ist.\n" "$keepGensDef" "$keepDaysDef"
    if auto_pick_profile "$include_sys"; then
      if is_system_profile && (( EUID != 0 )); then
        printf "Automatisch gewähltes Profil: %s (via sudo)\n" "$profile"
      else
        printf "Automatisch gewähltes Profil: %s\n" "$profile"
      fi
    else
      printf "Hinweis: Kein Profil mit Generationen gefunden.\n"
    fi
  elif (( $# <= 2 )); then
    printf "\nFehler: Zu wenige Argumente.\n\n" >&2
    usage; return 1
  elif (( $# > 3 )); then
    printf "\nFehler: Zu viele Argumente.\n\n" >&2
    usage; return 2
  else
    # Numerisch validieren
    if [[ ! $1 =~ ^[0-9]+$ ]]; then printf "keep-generations muss eine Zahl >=1 sein.\n"; return 1; fi
    if [[ ! $2 =~ ^[0-9]+$ ]]; then printf "keep-days muss eine Zahl >=0 sein.\n"; return 1; fi

    keepGens=$1
    keepDays=$2
    (( keepGens < 1 )) && keepGens=1
    (( keepDays < 0 )) && keepDays=0

    # Profil aus drittem Argument wählen
    if (( EUID != 0 )); then
      case "$3" in
        user|default)  profile="$HOME/.nix-profile" ;;
        home-manager)  profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager" ;;
        channels)      profile="/nix/var/nix/profiles/per-user/$USER/channels" ;;
        system)        profile="/nix/var/nix/profiles/system" ;; # via sudo
        *)
          printf "\nFehler: Drittes Argument unbekannt. Erlaubt: user | home-manager | channels | system\n\n"
          usage; return 3 ;;
      esac
    else
      case "$3" in
        system)        profile="/nix/var/nix/profiles/system" ;;
        user|default)  profile="/nix/var/nix/profiles/default" ;;
        home-manager|channels)
          printf "Hinweis: Für %s bitte als normaler User starten.\n" "$3"
          ;;
        *)
          printf "\nFehler: Drittes Argument unbekannt. Erlaubt: user | system\n\n"
          usage; return 3 ;;
      esac
    fi
    printf "OK!   Keep Gens = %s   Keep Days = %s\n\n" "$keepGens" "$keepDays"
  fi

  # Wenn System-Profil gewählt und wir sind kein Root: vorab sudo anfordern
  if (( EUID != 0 )) && is_system_profile; then
    ensure_sudo || echo "Ohne sudo können System-Generationen nicht bearbeitet werden."
  fi

  printf "Arbeite auf Profil: %s\n\n" "$profile"

  # ----------------- Hauptlogik -----------------

  # Generationsliste einlesen (ggf. via sudo)
  mapfile -t nixGens < <(list_generations \
                       | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
                       | tr '\t' ' ' | tr -s ' ')
  if (( ''${#nixGens[@]} == 0 )); then
    echo "Keine Generationen gefunden."
    return 9
  fi

  timeNow=$(date +%s)

  # Älteste Generation
  IFS=' ' read -r oldestGen oldestDate _ <<< "''${nixGens[0]}"
  printf "%-30s %s\n" "oldest generation:" "$oldestGen"
  printf "%-30s %s\n" "oldest generation created:" "$oldestDate"
  oldestTime=$(date -d "$oldestDate" +%s)
  oldestElapsedSecs=$(( timeNow - oldestTime ))
  printf "%-30s %s\n" "minutes before now:" $(( oldestElapsedSecs/60 ))
  printf "%-30s %s\n" "hours before now:"   $(( oldestElapsedSecs/3600 ))
  printf "%-30s %s\n" "days before now:"    $(( oldestElapsedSecs/86400 ))

  # Aktuelle Generation
  currentGen=""
  for line in "''${nixGens[@]}"; do
    if [[ $line == *"(current)"* ]]; then
      IFS=' ' read -r genNumber genDate _ <<< "$line"
      currentGen=$genNumber
      currentDate=$genDate
      printf "%-30s %s\n" "current generation:" "$currentGen"
      printf "%-30s %s\n" "current generation created:" "$currentDate"
      currentTime=$(date -d "$currentDate" +%s)
      currentElapsedSecs=$(( timeNow - currentTime ))
      printf "%-30s %s\n" "minutes before now:" $(( currentElapsedSecs/60 ))
      printf "%-30s %s\n" "hours before now:"   $(( currentElapsedSecs/3600 ))
      printf "%-30s %s\n" "days before now:"    $(( currentElapsedSecs/86400 ))
      break
    fi
  done
  if [[ -z ''${currentGen:-} ]]; then
    echo "Warnung: Konnte 'current' Generation nicht bestimmen."
    return 10
  fi

  # Prüfkriterien (Frühabbruch nur wenn BEIDE Kriterien „behalten“ signalisieren)
  timeBetweenOldestAndCurrent=$(( currentTime - oldestTime ))
  elapsedDays=$(( timeBetweenOldestAndCurrent / 86400 ))
  generationsDiff=$(( currentGen - oldestGen ))

  if (( elapsedDays <= keepDays )) && (( generationsDiff < keepGens )); then
    printf "Alle Generationen sind jung (<= %s Tage) UND insgesamt <= %s zurück.\n\tNichts zu tun!\n" "$keepDays" "$keepGens"
    return 4
  fi

  printf "\tEs gibt etwas zu löschen …\n"
  declare -A gens=()

  # Kandidaten: (älter als keepDays) ODER (weiter zurück als keepGens)
  for line in "''${nixGens[@]}"; do
    IFS=' ' read -r genNumber genDate _ <<< "$line"
    [[ "$genNumber" == "$currentGen" ]] && continue
    genTime=$(date -d "$genDate" +%s)
    genDaysOld=$(( (timeNow - genTime) / 86400 ))
    genDiff=$(( currentGen - genNumber ))

    if (( genDaysOld > keepDays )) || (( genDiff >= keepGens )); then
      gens["$genNumber"]="$genDate, $genDaysOld day(s) old"
    fi
  done

  if (( ''${#gens[@]} == 0 )); then
    printf "Keine löschbaren Generationen gemäß Regeln gefunden.\n"
    return 0
  fi

  printf "\nGefundene Generation(en) zum Löschen:\n"
  for K in "''${!gens[@]}"; do
    printf "generation %s\t %s\n" "$K" "''${gens[$K]}"
  done
  printf "\n"

  # Bestätigen: löschen + Boot-Refresh + GC
  choose () {
    local default="$1" prompt="$2" answer
    read -r -p "$prompt" answer
    [ -z "$answer" ] && answer="$default"

    case "$answer" in
      [yY1])
        # ''${!gens[@]} expandiert die zu löschenden Generationsnummern (absichtlich unquoted)
        if is_system_profile; then
          # shellcheck disable=SC2086
          run_root nix-env --delete-generations -p "$profile" ''${!gens[@]}
        else
          # shellcheck disable=SC2086
          nix-env --delete-generations -p "$profile" ''${!gens[@]}
        fi
        refresh_boot_entries
        run_gc
        return 0 ;;
      [nN0])
        printf "Ok, nichts gelöscht. Beende …\n"
        return 6 ;;
      *)
        printf "Unerwartete Eingabe '%s'!\n" "$answer" >&2
        return 7 ;;
    esac
  }

  choose "y" "Diese löschen? [Y/n]: " || return $?
}

if [[ $clean_generations =~ ^[Yy]$ ]]; then
  run_cleanup "$@"
fi

#--------------------------------------------------------------------------------


# URL des Git-Repositories festlegen
repo_url="git@github.com:tombo09/data.git" 

echo -ne "\e[1;34m>>\e[0m Möchtest du das Repository aktualisieren? (Y/n): "
read antwort
antwort=''${antwort:-y}

if [[ $antwort == "y" || $antwort == "Y" ]]; then
  temp_dir=$(mktemp -d 2>/dev/null)

  echo "Bitte stecken Sie Ihren YubiKey ein."
  while [ $(lsusb | grep -c 'Yubico') -eq 0 ]; do
    echo -ne "Warten auf YubiKey...\r"
    sleep 0.7
    echo -ne "                     \r"
    sleep 0.7
  done
  echo "YubiKey erkannt."


  # Ins lokale Repository wechseln
  cd /home/tom/data

  # Dateien ins lokale Repository kopieren
  cp -r /home/tom/.mozilla/firefox/tom.default/sessionstore-backups/* /home/tom/data/firefox/session/
  cp /home/tom/.mozilla/firefox/tom.default/key4.db /home/tom/data/firefox/settings/key4.db
  cp /home/tom/.mozilla/firefox/tom.default/logins.json /home/tom/data/firefox/settings/logins.json
  cp /home/tom/.mozilla/firefox/tom.default/user.js /home/tom/data/firefox/settings/user.js
  cp /home/tom/.mozilla/firefox/tom.default/places.sqlite /home/tom/data/firefox/settings/places.sqlite
  cp -r /home/tom/.mozilla/firefox/tom.default/extensions/ /home/tom/data/firefox/settings/

  # Änderungen committen und pushen
  git add .
  git commit -m "Update data"
  git push
  echo "Data wurde erfolgreich aktualisiert und gepusht."

  cd /home/tom/
else
  echo "Aktualisierung wurde abgebrochen."
fi

exit
  '')

(pkgs.writeShellScriptBin "vpn-toggle.sh" ''
VPN_CONFIG="/etc/vpn.nordvpn.com.udp.ovpn"

if ip a | grep -q "tun0"; then
  kitty -e bash -c "echo 'VPN wird getrennt...'; sudo pkill openvpn"
else
  kitty -e bash -c "echo 'VPN wird verbunden...'; sudo openvpn --config \"$VPN_CONFIG\" --daemon"
fi
'')

(pkgs.writeShellScriptBin "vpn-status.sh" ''
if ip a | grep -q "tun0"; then
  echo "🔒"
else
  echo "🔓"
fi
'')


/*(let

  pkgs = import <nixpkgs> {};

  myPython = pkgs.python3.withPackages (ps: with ps; [
    requests
  ]);
  pythonScript = pkgs.writeTextFile {
    name = "polybar-position.py";
    text = ''
import os
import subprocess
import time
import json
import hmac
import hashlib
import base64
import requests


# ——— Pfade für xbindkeys & Statusfiles ———
bindxkeys_path   = "/home/tom/.xbindkeysrc"
option_file      = "/tmp/option1_status"
state_file       = "/tmp/position_state.json"

with open("/run/agenix/stripe-api-key", "r") as f:
    API_KEY = f.read().strip()

API_SECRET= ''
API_PASSPHRASE = ' '

# ——— Endpunkte ———
BASE_URL          = "https://api.bitget.com"
ALL_POS_ENDPOINT  = "/api/v2/mix/position/all-position"
HIST_POS_ENDPOINT = "/api/v2/mix/position/history-position"

def sign_request(method: str, endpoint: str, query: str = "", body: str = "") -> dict:
    ts      = str(int(time.time() * 1000))
    message = ts + method + endpoint + query + body
    sig     = base64.b64encode(
        hmac.new(API_SECRET.encode(), message.encode(), hashlib.sha256).digest()
    ).decode()
    return {
        "ACCESS-KEY":        API_KEY,
        "ACCESS-SIGN":       sig,
        "ACCESS-TIMESTAMP":  ts,
        "ACCESS-PASSPHRASE": API_PASSPHRASE,
        "Content-Type":      "application/json",
    }

def fetch_current_positions():
    query = "?productType=USDT-FUTURES&marginCoin=USDT"
    headers = sign_request("GET", ALL_POS_ENDPOINT, query)
    data = requests.get(BASE_URL + ALL_POS_ENDPOINT + query, headers=headers).json().get("data", [])
    out = []
    for pos in data:
        init = float(pos.get("marginSize", 0))
        pnl  = float(pos.get("unrealizedPL", 0))
        pct  = float(pos.get("percentage", 0))
        side = pos.get("holdSide", "").upper()
        entry= float(pos.get("openPriceAvg", 0))
        if init > 0:
            out.append({
                "initialMargin": init,
                "unrealizedPnl": pnl,
                "percentage":    pct,
                "side":          side,
                "entryPrice":    entry,
            })
    return out

def fetch_history_positions():
    query = "?productType=USDT-FUTURES"
    headers = sign_request("GET", HIST_POS_ENDPOINT, query)
    data = requests.get(BASE_URL + HIST_POS_ENDPOINT + query, headers=headers).json()
    return data.get("data", {}).get("list", [])

def compute_last_net(prev_size: float):
    history = fetch_history_positions()
    if history:
        first = history[0]
        net  = float(first.get("netProfit", 0))
        pct  = (net / prev_size * 100) if prev_size > 0 else 0.0
        return net, pct
    return 0.0, 0.0

def create_xbindkeys_config():
    with open(bindxkeys_path, "w") as f:
        f.write("""
"shortcut-execute.sh -a openLong -l 30 -g 2 -e limit_loop"
  Control+Alt + b

"shortcut-execute.sh -a openShort -l 30 -g 2 -e limit_loop"
  Control+Alt + s

"shortcut-execute.sh -a openLong -l 30 -g 2 -e market"
  Alt+Shift + b

"shortcut-execute.sh -a openShort -l 30 -g 2 -e market"
  Alt+Shift + s

"shortcut-execute.sh -a closeLong -g All -e market"
  Control+Alt+Shift + b

"shortcut-execute.sh -a closeShort -g All -e market"
  Control+Alt+Shift + s

"shortcut-execute.sh -a closeLong -g 2 -e market"
  Control+Shift+Tab + b

"shortcut-execute.sh -a closeShort -g 2 -e market"
  Control+Shift+Tab + s 

"shortcut-execute.sh -a closeLong -g All -e limit_loop"
  Control+Tab + b

"shortcut-execute.sh -a closeShort -g All -e limit_loop"
  Control+Tab + s
""")

def start_xbindkeys():
    if subprocess.run(["pgrep", "xbindkeys"], capture_output=True).returncode != 0:
        subprocess.Popen(["xbindkeys"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def stop_xbindkeys():
    subprocess.run(["killall", "xbindkeys"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def check_option_status():
    return os.path.exists(option_file) and open(option_file).read().strip() == "on"

def load_state():
    if os.path.exists(state_file):
        try:
            return json.load(open(state_file))
        except:
            pass
    return {"last_size":0.0,"last_pnl":0.0,"last_pct":0.0,"pnl_until":0.0}

def save_state(s):
    with open(state_file,"w") as f:
        json.dump(s, f)

def get_positions_data():
    lst = fetch_current_positions()
    total_size = sum(p["initialMargin"] for p in lst)
    total_pnl  = sum(p["unrealizedPnl"]  for p in lst)
    parts = []
    for p in lst:
        init = p["initialMargin"]
        pnl  = p["unrealizedPnl"]
        roe  = (pnl / init * 100) if init > 0 else 0.0
        parts.append(
            f"{p['side']} Entry:{p['entryPrice']:.1f} "
            f"Marge:{init:.1f} Pnl:{pnl:.2f} Roe:{roe:.3f}%"
        )
    return total_size, total_pnl, " | ".join(parts)

def get_polybar_output():
    state = load_state()
    now   = time.time()
    prev_size, prev_pnl, prev_pct = state["last_size"], state["last_pnl"], state["last_pct"]
    curr_size, curr_pnl, details   = get_positions_data()

    if curr_size == 0.0 and prev_size > 0.0:
        net, pct = compute_last_net(prev_size)
        state["last_pnl"]  = net
        state["last_pct"]  = pct
        state["pnl_until"] = now + 4.0
    else:
        if now > state.get("pnl_until",0):
            state["last_pnl"] = curr_pnl
            state["last_pct"] = (curr_pnl/curr_size*100) if curr_size>0 else prev_pct

    state["last_size"] = curr_size
    save_state(state)

    if now < state.get("pnl_until",0):
        return f"Pnl:{state['last_pnl']:.2f} ({state['last_pct']:.3f}%)"

    base = "on" if check_option_status() else "off"
    return f"{base} | {details}" if details else base

def main():
    create_xbindkeys_config()
    if check_option_status():
        start_xbindkeys()
    else:
        stop_xbindkeys()
    print(get_polybar_output())

if __name__ == "__main__":
    main()
   '';
  };
in
pkgs.writeShellScriptBin "polybar-position-exe.sh" ''
#!/usr/bin/env bash
${myPython}/bin/python ${pythonScript}

''
)
*/

(let
  pythonScript = pkgs.writeTextFile {
    name = "rectangle.py";
    text = ''
#!/usr/bin/env python3
import sys
from PyQt5 import QtWidgets, QtCore, QtGui

class ResizableRectangle(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()

        self.setGeometry(300, 300, 200, 100)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)
        self.setWindowFlags(QtCore.Qt.FramelessWindowHint | QtCore.Qt.WindowStaysOnTopHint | QtCore.Qt.X11BypassWindowManagerHint)

        self.dragging = False
        self.resizing = False
        self.margin = 7  # Ändern um minimale Groesse des Rechtecks und Empfindlichkeit an den Ecken/Kanten zu veraendern 
        self.resize_direction = None

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.detect_resize_direction(event)
            if self.resize_direction:
                self.resizing = True
                self.resize_start_pos = event.globalPos()
                self.resize_start_geometry = self.geometry()
            else:
                self.dragging = True
                self.drag_start_pos = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()

    def mouseMoveEvent(self, event):
        if self.dragging:
            self.move(event.globalPos() - self.drag_start_pos)
            event.accept()
        elif self.resizing:
            self.perform_resize(event)
            event.accept()
        else:
            self.update_cursor_shape(event)

    def mouseReleaseEvent(self, event):
        self.dragging = False
        self.resizing = False
        self.resize_direction = None
        event.accept()

    def detect_resize_direction(self, event):
        rect = self.rect()
        x, y, w, h = rect.x(), rect.y(), rect.width(), rect.height()
        mx, my = event.x(), event.y()

        if mx <= self.margin and my <= self.margin:
            self.resize_direction = 'top_left'
        elif mx >= w - self.margin and my <= self.margin:
            self.resize_direction = 'top_right'
        elif mx <= self.margin and my >= h - self.margin:
            self.resize_direction = 'bottom_left'
        elif mx >= w - self.margin and my >= h - self.margin:
            self.resize_direction = 'bottom_right'
        elif mx <= self.margin:
            self.resize_direction = 'left'
        elif mx >= w - self.margin:
            self.resize_direction = 'right'
        elif my <= self.margin:
            self.resize_direction = 'top'
        elif my >= h - self.margin:
            self.resize_direction = 'bottom'
        else:
            self.resize_direction = None

    def perform_resize(self, event):
        if not self.resize_direction:
            return

        delta = event.globalPos() - self.resize_start_pos
        geom = self.resize_start_geometry

        if self.resize_direction == 'top_left':
            new_geom = QtCore.QRect(geom.left() + delta.x(), geom.top() + delta.y(), geom.width() - delta.x(), geom.height() - delta.y())
        elif self.resize_direction == 'top_right':
            new_geom = QtCore.QRect(geom.left(), geom.top() + delta.y(), geom.width() + delta.x(), geom.height() - delta.y())
        elif self.resize_direction == 'bottom_left':
            new_geom = QtCore.QRect(geom.left() + delta.x(), geom.top(), geom.width() - delta.x(), geom.height() + delta.y())
        elif self.resize_direction == 'bottom_right':
            new_geom = QtCore.QRect(geom.left(), geom.top(), geom.width() + delta.x(), geom.height() + delta.y())
        elif self.resize_direction == 'left':
            new_geom = QtCore.QRect(geom.left() + delta.x(), geom.top(), geom.width() - delta.x(), geom.height())
        elif self.resize_direction == 'right':
            new_geom = QtCore.QRect(geom.left(), geom.top(), geom.width() + delta.x(), geom.height())
        elif self.resize_direction == 'top':
            new_geom = QtCore.QRect(geom.left(), geom.top() + delta.y(), geom.width(), geom.height() - delta.y())
        elif self.resize_direction == 'bottom':
            new_geom = QtCore.QRect(geom.left(), geom.top(), geom.width(), geom.height() + delta.y())

        if new_geom.width() >= self.margin * 2 and new_geom.height() >= self.margin * 2:
            self.setGeometry(new_geom)

    def update_cursor_shape(self, event):
        rect = self.rect()
        x, y, w, h = rect.x(), rect.y(), rect.width(), rect.height()
        mx, my = event.x(), event.y()

        if mx <= self.margin and my <= self.margin:
            self.setCursor(QtCore.Qt.SizeFDiagCursor)
        elif mx >= w - self.margin and my <= self.margin:
            self.setCursor(QtCore.Qt.SizeBDiagCursor)
        elif mx <= self.margin and my >= h - self.margin:
            self.setCursor(QtCore.Qt.SizeBDiagCursor)
        elif mx >= w - self.margin and my >= h - self.margin:
            self.setCursor(QtCore.Qt.SizeFDiagCursor)
        elif mx <= self.margin:
            self.setCursor(QtCore.Qt.SizeHorCursor)
        elif mx >= w - self.margin:
            self.setCursor(QtCore.Qt.SizeHorCursor)
        elif my <= self.margin:
            self.setCursor(QtCore.Qt.SizeVerCursor)
        elif my >= h - self.margin:
            self.setCursor(QtCore.Qt.SizeVerCursor)
        else:
            self.setCursor(QtCore.Qt.ArrowCursor)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setBrush(QtGui.QBrush(QtGui.QColor(0, 0, 0)))
        painter.drawRect(self.rect())

class RectangleApp(QtWidgets.QApplication):
    def __init__(self, argv):
        super().__init__(argv)
        self.rectangles = []

    def add_rectangle(self):
        rect = ResizableRectangle()
        rect.show()
        self.rectangles.append(rect)

def main():
    app = RectangleApp(sys.argv)
    app.add_rectangle()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
    '';
  };
in

# Ein Bash-Skript erstellen, das das Python-Skript ausführt
pkgs.writeShellScriptBin "create-rectangle" ''
#!/usr/bin/env bash
nix-shell -p qt5Full python310Packages.pyqt5 --run "python ${pythonScript}"
'')


];
}




