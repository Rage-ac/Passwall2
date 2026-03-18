# PassWall2 APK Repository

Auto-updated and signed APK package repository for [PassWall2](https://github.com/Openwrt-Passwall/openwrt-passwall2) on OpenWrt.

## How it works

GitHub Actions checks for new upstream releases every 6 hours. When a new version is detected:

1. All APK packages and per-architecture ZIP archives are downloaded
2. ZIP archives are extracted and organized by architecture
3. All `.apk` packages are signed with the repository RSA key
4. A new GitHub Release is created with all signed packages

## Installation on Router

### Step 1: Add the signing key

```sh
wget -O /etc/apk/keys/passwall2-repo.rsa.pub \
  https://rage-ac.github.io/Passwall2/keys/passwall2-repo.rsa.pub
```

### Step 2: Install packages

Download `.apk` files from [Releases](../../releases/latest) for your architecture and install:

```sh
apk add luci-app-passwall2-*.apk
```

Or download the full architecture ZIP:

```sh
wget https://github.com/Rage-ac/Passwall2/releases/latest/download/passwall2_signed_apk_aarch64_generic.zip
unzip passwall2_signed_apk_aarch64_generic.zip
apk add *.apk
```

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

## Upstream

- [Openwrt-Passwall/openwrt-passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2)
