#!/bin/sh
# Generate RSA key pair for APK package signing
# The private key must be added as a GitHub Actions secret: APK_SIGNING_KEY
# The public key should be committed to keys/ directory

set -e

KEY_NAME="passwall2-repo"
KEY_DIR="$(cd "$(dirname "$0")/../keys" && pwd)"

echo "Generating RSA-4096 key pair..."
openssl genrsa -out "${KEY_DIR}/${KEY_NAME}.rsa" 4096
openssl rsa -in "${KEY_DIR}/${KEY_NAME}.rsa" -pubout -out "${KEY_DIR}/${KEY_NAME}.rsa.pub"

echo ""
echo "=== Keys generated ==="
echo "Private key: ${KEY_DIR}/${KEY_NAME}.rsa"
echo "Public key:  ${KEY_DIR}/${KEY_NAME}.rsa.pub"
echo ""
echo "=== Next steps ==="
echo "1. Add the private key as a GitHub secret named APK_SIGNING_KEY:"
echo "   cat ${KEY_DIR}/${KEY_NAME}.rsa | gh secret set APK_SIGNING_KEY"
echo ""
echo "2. Commit the public key to the repository:"
echo "   git add ${KEY_DIR}/${KEY_NAME}.rsa.pub"
echo ""
echo "3. DELETE the private key from your local machine:"
echo "   rm ${KEY_DIR}/${KEY_NAME}.rsa"
echo ""
echo "WARNING: Never commit the private key to the repository!"
