# PassWall2 APK Repository

[![Update PassWall2 Packages](https://github.com/Rage-ac/Passwall2/actions/workflows/sync-passwall2.yml/badge.svg)](https://github.com/Rage-ac/Passwall2/actions/workflows/sync-passwall2.yml)
[![pages-build-deployment](https://github.com/Rage-ac/Passwall2/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/Rage-ac/Passwall2/actions/workflows/pages/pages-build-deployment)

Auto-updated and signed APK package repository for **PassWall2** on OpenWrt.

> **Note:** This repository provides **only PassWall2** (version 2). PassWall v1 is not supported.

**Website:** [rage-ac.github.io](https://rage-ac.github.io/)

## How it works

GitHub Actions checks for new upstream releases every 6 hours. When a new version is detected:

1. All APK packages and per-architecture ZIP archives are downloaded
2. Packages are signed with the repository RSA key
3. `APKINDEX.tar.gz` is generated and signed for each architecture
4. The generated tree is verified (every expected architecture present, every index intact)
5. APK repository is deployed to GitHub Pages and the live site is smoke tested
6. A GitHub Release is created with per-arch ZIP archives

Upstream publishes a release in stages, so a build is deferred while upstream ships fewer
architectures than we already provide, and any architecture that is still missing is carried
over from the previous release. That way the published repository never loses an architecture
mid-upload, which would make `apk update` answer `HTTP 404: Not Found` for the affected routers.

Every deployment is also checked with a real apk-tools v3 client before and after publishing.

## Technical requirements

| Parameter | Minimum |
|---|---|
| Processor | 700 MHz |
| RAM | 256 MB |
| Firmware | OpenWrt (APK package manager) |

> Routers with 128 MB RAM should use OpenWrt 22.03.3.
>
> WAN and LAN addresses **must** be different.

## Supported protocols

| Protocol | Xray | Sing-Box |
|---|---|---|
| VLESS | ✅ | ✅ |
| VMESS | ✅ | ✅ |
| REALITY | ✅ | ❌ |
| TROJAN | ✅ | ✅ |
| SHADOWSOCKS | ✅ | ✅ |
| WIREGUARD | ✅ | ✅ |
| SOCKS | ✅ | ✅ |
| HTTP | ✅ | ✅ |
| HYSTERIA2 | ❌ | ✅ |
| TUIC | ❌ | ✅ |

## Features

- Single-command installation via `apk`
- Automatic package updates every 6 hours from upstream
- All packages are signed with a repository RSA key
- 13 supported architectures (ARM, ARM64, MIPS, x86_64) — whatever upstream publishes
- Kill switch functionality
- TLS fragmentation support
- WARP connection support

## Installation on Router

### Option 1: APK Repository (recommended)

Add the signing key and repository — packages will be installed and updated via `apk`:

```sh
# Add signing key
wget -O /etc/apk/keys/passwall2-repo.rsa.pub \
  https://rage-ac.github.io/Passwall2/keys/passwall2-repo.rsa.pub

# Add repository (only if not already added)
grep -q 'rage-ac.github.io/Passwall2' /etc/apk/repositories || \
  echo "https://rage-ac.github.io/Passwall2/packages" >> /etc/apk/repositories

# Install
apk update
apk add luci-app-passwall2
```

### Option 2: Manual download

Download ZIP from [Releases](../../releases/latest) for your architecture:

```sh
wget https://github.com/Rage-ac/Passwall2/releases/latest/download/passwall2_signed_apk_aarch64_generic.zip
unzip passwall2_signed_apk_aarch64_generic.zip
apk add --allow-untrusted *.apk
```

## Repository URL

```
https://rage-ac.github.io/Passwall2/packages
```

`apk` automatically appends your device architecture (e.g. `aarch64_cortex-a53`) to the URL.

## Signing key verification

All packages are signed with a repository RSA key. After downloading the key, verify its integrity:

**Key URL:** `https://rage-ac.github.io/Passwall2/keys/passwall2-repo.rsa.pub`

| Algorithm | Hash |
|---|---|
| SHA-256 | `b62fb975e40d489c914c73bcca477ecd8821e7901ad34706c92807e919d2cd89` |
| SHA-1 | `da86ba359996d347d4205b133ad5eb9acc9dfcb1` |
| MD5 | `0a6b509e115ffc2d0ff077ce638fdb53` |

**Verify after download:**

```sh
# Download the key
wget -O /tmp/passwall2-repo.rsa.pub \
  https://rage-ac.github.io/Passwall2/keys/passwall2-repo.rsa.pub

# Check SHA-256
sha256sum /tmp/passwall2-repo.rsa.pub
# Expected: b62fb975e40d489c914c73bcca477ecd8821e7901ad34706c92807e919d2cd89

# If openssl is available on the router:
openssl pkey -pubin -in /tmp/passwall2-repo.rsa.pub -outform DER | sha256sum
# Expected: b62fb975e40d489c914c73bcca477ecd8821e7901ad34706c92807e919d2cd89
```

## Supported architectures

The set follows upstream — these are the architectures currently published:

| Architecture | Devices |
|---|---|
| `aarch64_cortex-a53` | Raspberry Pi 3/4, many ARM routers |
| `aarch64_cortex-a72` | Raspberry Pi 4/5 |
| `aarch64_generic` | Generic ARM64 |
| `arm_cortex-a7` | Many budget ARM routers |
| `arm_cortex-a7_neon-vfpv4` | ARM routers with NEON |
| `arm_cortex-a8_vfpv3` | TI OMAP3 / Beagle series |
| `arm_cortex-a9` | Older ARM routers |
| `arm_cortex-a15_neon-vfpv4` | Marvell Armada 38x |
| `mips_24kc` | MediaTek MT7621 and similar |
| `mips_mips32` | Generic MIPS |
| `mipsel_24kc` | MediaTek little-endian |
| `mipsel_mips32` | Generic MIPS little-endian |
| `x86_64` | x86 PCs / virtual machines |
| `noarch` | Architecture-independent packages (`luci-app`, translations) |

## Development

The workflow logic lives in [`scripts/`](scripts) and is covered by tests:

```sh
./tests/run-tests.sh                 # gate logic, repository verification, workflow wiring

# check the live repository the way apk sees it
./scripts/verify-repo.sh --url https://rage-ac.github.io/Passwall2/packages \
  --expect aarch64_generic,arm_cortex-a7_neon-vfpv4,noarch

# end-to-end with a real apk-tools v3 client (downloads apk.static, Linux only)
./scripts/apk-smoke-test.sh --url https://rage-ac.github.io/Passwall2/packages \
  --arch arm_cortex-a7_neon-vfpv4
```

Troubleshooting `apk update` against this repository:

| Message | Cause |
|---|---|
| `HTTP 404: Not Found` | the architecture is not published — check `/etc/apk/arch` and the [supported list](#supported-architectures) |
| `UNTRUSTED signature` | the signing key is not in `/etc/apk/keys/` |
| `unexpected end of file` | the index download was interrupted or is corrupt — retry, or `apk update --no-cache` |

Tests run in CI on every push, and a daily workflow re-checks the published repository.

## Upstream

- [Openwrt-Passwall/openwrt-passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2)

## License

GPLv3
