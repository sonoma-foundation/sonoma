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

# Archive name and version
archName="sonoma-cli-x86_64-unknown-linux-gnu.tar.bz2"
version="1.14.12"

# Creating a temporary directory
tempDir="$(mktemp -d)"
echo $temp_dir
cd "$tempDir"

# Downloading and unpacking the Sonoma CLI Binary Archive
sonomaURL="https://github.com/convowork1/sonoma/releases/download/$version/$archName"
curl -LJO $sonomaURL
tar jxf sonoma-cli-x86_64-unknown-linux-gnu.tar.bz2

# Defining the installation directory
installDir="$HOME/bin/sonoma"  

# Copying the Sonoma CLI binary to the installation directory
mkdir -p "$installDir"
cp -R ./* "$installDir"
rm $installDir/$archName

# Check for the presence of .bash_profile
if [ -f "$HOME/.bash_profile" ]; then
    # Add the bin path to .bash_profile
    if ! grep -q "$installDir" "$HOME/.bash_profile"; then
        echo "export PATH=\"$installDir:\$PATH\"" >> "$HOME/.bash_profile"
        echo "Bin path successfully added to .bash_profile"
    else
        echo "Bin path already exists in .bash_profile"
    fi
# Check for the presence of .profile
elif [ -f "$HOME/.profile" ]; then
    # Add the bin path to .profile
    if ! grep -q "$installDir" "$HOME/.profile"; then
        echo "export PATH=\"$installDir:\$PATH\"" >> "$HOME/.profile"
        echo "Bin path successfully added to .profile"
    else
        echo "Bin path already exists in .profile"
    fi
else
    echo "Neither .profile nor .bash_profile found"
    # Exporting a path to use the Sonoma CLI
    echo "Please update your PATH environment variable to include the solana programs:"
    echo "Use "export PATH="$installDir:\$PATH"""
fi

echo "Sonoma CLI has been installed successfully"
echo "You can now use 'sonoma' command in your terminal after restart"