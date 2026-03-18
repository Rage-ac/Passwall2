# PassWall2 APK Repository

Auto-updated APK package repository for [PassWall2](https://github.com/Openwrt-Passwall/openwrt-passwall2) on OpenWrt.

## How it works

GitHub Actions checks for new upstream releases every 6 hours. When a new version is detected:

1. All APK packages and per-architecture ZIP archives are downloaded
2. ZIP archives are extracted
3. A new GitHub Release is created with all packages

## Supported architectures

| Architecture | Devices |
|---|---|
| `aarch64_cortex-a53` | Raspberry Pi 3/4, many ARM routers |
| `aarch64_cortex-a72` | Raspberry Pi 4/5 |
| `aarch64_generic` | Generic ARM64 |
| `arm_cortex-a7` | Many budget ARM routers |
| `arm_cortex-a9` | Older ARM routers |
| `mips_24kc` | MediaTek MT7621 and similar |
| `mipsel_74kc` | Broadcom BCM47xx |
| `x86_64` | x86 PCs / virtual machines |

## Installation

### Download APK manually

Go to [Releases](../../releases/latest), download the `.apk` files for your architecture and install:

```sh
apk add --allow-untrusted luci-app-passwall2-*.apk
```

### Or download a ZIP with all packages for your arch

```sh
wget https://github.com/<owner>/Passwall2-repository/releases/latest/download/passwall_packages_apk_aarch64_generic.zip
unzip passwall_packages_apk_aarch64_generic.zip
apk add --allow-untrusted *.apk
```

## Manual trigger

Actions → Update PassWall2 Packages → Run workflow

## Upstream

- [Openwrt-Passwall/openwrt-passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2)
