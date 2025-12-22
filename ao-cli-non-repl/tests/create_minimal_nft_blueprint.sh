#!/bin/bash

# Create minimal NFT blueprint by removing comments and print statements

echo "Creating minimal NFT blueprint..."

# Remove comments (lines starting with --) and empty lines
# Remove print statements but keep other code
sed -e '/^[[:space:]]*--/d' \
    -e '/^[[:space:]]*$/d' \
    -e '/^[[:space:]]*print(/d' \
    -e 's/[[:space:]]*--.*$//' \
    ao-legacy-nft-blueprint.lua > ao-legacy-nft-blueprint-minimal.lua

echo "Minimal blueprint created. Checking size..."
wc -l ao-legacy-nft-blueprint-minimal.lua
ls -lh ao-legacy-nft-blueprint-minimal.lua

echo "Comparing sizes:"
echo "Original:"
wc -l ao-legacy-nft-blueprint.lua
ls -lh ao-legacy-nft-blueprint.lua
