# PassWall2 APK Repository

Auto-updated and signed APK package repository for [PassWall2](https://github.com/Openwrt-Passwall/openwrt-passwall2) on OpenWrt.

## How it works

GitHub Actions checks for new upstream releases every 6 hours. When a new version is detected:

1. All APK packages and per-architecture ZIP archives are downloaded
2. ZIP archives are extracted and organized by architecture
3. All `.apk` packages are signed with the repository RSA key
4. A new GitHub Release is created with all signed packages

## Setup: Signing Key

Packages are signed with an RSA key so they can be installed on routers without `--allow-untrusted`.

### 1. Generate the key pair

```sh
git clone <this-repo>
cd Passwall2-repository
chmod +x scripts/generate-keys.sh
./scripts/generate-keys.sh
```

This creates:
- `keys/passwall2-repo.rsa` — private key (DO NOT commit)
- `keys/passwall2-repo.rsa.pub` — public key (commit this)

### 2. Add the private key as a GitHub Actions secret

```sh
cat keys/passwall2-repo.rsa | gh secret set APK_SIGNING_KEY
```

Or go to **Settings → Secrets and variables → Actions → New repository secret**, name it `APK_SIGNING_KEY`, and paste the contents of `keys/passwall2-repo.rsa`.

### 3. Commit the public key and delete the private key

```sh
git add keys/passwall2-repo.rsa.pub
git commit -m "Add APK signing public key"
git push
rm keys/passwall2-repo.rsa
```

### 4. Run the workflow

Go to **Actions → Update PassWall2 Packages → Run workflow** to trigger the first sync.

## Installation on Router

### Step 1: Add the signing key

Download the public key to your router:

```sh
wget -O /etc/apk/keys/passwall2-repo.rsa.pub \
  https://raw.githubusercontent.com/<owner>/Passwall2-repository/main/keys/passwall2-repo.rsa.pub
```

Or copy it manually via SCP:

```sh
scp keys/passwall2-repo.rsa.pub root@<router-ip>:/etc/apk/keys/
```

### Step 2: Install packages

Download `.apk` files from [Releases](../../releases/latest) for your architecture and install:

```sh
# No --allow-untrusted needed since the key is installed
apk add luci-app-passwall2-*.apk
```

Or download the full architecture ZIP:

```sh
wget https://github.com/<owner>/Passwall2-repository/releases/latest/download/passwall_packages_apk_aarch64_generic.zip
unzip passwall_packages_apk_aarch64_generic.zip
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
