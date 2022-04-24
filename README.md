Arch Linux installer and configurator. Tailored to my personal preferences.

## Why?

I often find myself re-installing Arch, and doing the same configuration over and over again. This project automates the process and for both installation and configuration.

## Some features

- Encryption
- Dual-boot support
- Sway (Wayland)
- Customized Waybar
- Minimalistic

## Usage

### Installer

The recommended way to install Arch in a dual-boot configuration is to use the Windows EFI partition. However, the default EFI partition made by Windows is too small. To fix this, we use the installer to create a EFI partition of a suitable size before installing Windows. This step is only needed when dual-booting.

```console
./installer.sh EFIONLY
```

After installing Windows (if dual-booting), we can run the installer.

```console
./installer.sh
```

### Configurator

I recommend modifying "configure.sh" to your preferences before running. The configurator has a range of parameters.

```console
./install.sh [options]
-c        Load only configs       (no package downloads)
-a        Load addons             (requires open sway)
-r        Reload all configs      (requires open sway)
-l        Laptop configuration
-h        Displays this message
```

## Known Issues

- Installer needs proper error handling
- Currently no automated AMD support
