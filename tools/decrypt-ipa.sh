#!/usr/bin/env bash
# Decrypts a kalgram-<build>.ipa.enc downloaded from the GitHub Actions artifact.
# Usage: tools/decrypt-ipa.sh kalgram-123.ipa.enc
# Asks for the KALGRAM_IPA_PASSWORD value; writes kalgram-123.ipa next to the input.
set -euo pipefail

in="${1:?usage: decrypt-ipa.sh <file.ipa.enc>}"
out="${in%.enc}"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$in" -out "$out"
echo "Done: $out"
