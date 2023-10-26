#!/usr/bin/env bash

set -e

# Checking the operating system and architecture
if [[ "$(uname)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This script is only supported on Linux x86_64"
  exit 1
fi

# Checking installed dependencies
if ! command -v curl &> /dev/null; then
  echo "curl is required but not installed. Please install curl"
  exit 1
fi

# Archive name
archName="sonoma-x86_64-unknown-linux-gnu.tar.bz2"

# Creating a temporary directory
tempDir="$(mktemp -d)"

# Downloading and unpacking the Sonoma CLI Binary Archive
sonomaURL="https://github.com/sonoma-foundation/sonoma/releases/download/testnet/$archName"

if curl -LJO $sonomaURL && tar jxf $archName -C "$tempDir"; then
    rm $archName
else
    echo "Failed to download and unpack Sonoma CLI Binary Archive"
    rm -rf "$tempDir"
    exit 1
fi

# Defining the installation directory
installDir="$HOME/.local/share/sonoma/install/active_release/bin"  

# Copying the Sonoma CLI binary to the installation directory
mkdir -p "$installDir"
cp -R "$tempDir"/* "$installDir"

# Set the config
devnet="http://3.74.241.65:8899"
"$installDir/sonoma" config set --url $devnet >  /dev/null 2>&1

rm -rf "$tempDir"

# Check for the presence of .bash_profile
if [ -f "$HOME/.bash_profile" ]; then
    # Add the bin path to .bash_profile
    if ! grep -q "$installDir" "$HOME/.bash_profile"; then
        echo -e "export PATH=\"$installDir:\$PATH\"" >> "$HOME/.bash_profile"
        echo "Bin path successfully added to .bash_profile"
    else
        echo "Bin path already exists in .bash_profile"
    fi
# Check for the presence of .profile
elif [ -f "$HOME/.profile" ]; then
    # Add the bin path to .profile
    if ! grep -q "$installDir" "$HOME/.profile"; then
        echo -e "\nexport PATH=\"$installDir:\$PATH\"" >> "$HOME/.profile"
        echo "Bin path successfully added to .profile"
    else
        echo "Bin path already exists in .profile"
    fi
else
    echo "Neither .profile nor .bash_profile found"
    echo "Please update your PATH environment variable to include the sonoma programs:"
    echo "Use 'export PATH=\"$installDir:\$PATH\"'"
fi

source ~/.profile

echo "Sonoma CLI has been installed successfully"
echo "You can now use 'sonoma' command in your terminal"