#!/usr/bin/env bash
#
# |cargo install| of the top-level crate will not install binaries for
# other workspace crates or native program crates.
here="$(dirname "$0")"
readlink_cmd="readlink"
echo "OSTYPE IS: $OSTYPE"
if [[ $OSTYPE == darwin* ]]; then
  # Mac OS X's version of `readlink` does not support the -f option,
  # But `greadlink` does, which you can get with `brew install coreutils`
  readlink_cmd="greadlink"

  if ! command -v ${readlink_cmd} &> /dev/null
  then
    echo "${readlink_cmd} could not be found. You may need to install coreutils: \`brew install coreutils\`"
    exit 1
  fi
fi

cargo="$("${readlink_cmd}" -f "${here}/../cargo")"

set -e

usage() {
  exitcode=0
  if [[ -n "$1" ]]; then
    exitcode=1
    echo "Error: $*"
  fi
  cat <<EOF
usage: $0 [+<cargo version>] [--debug] [--validator-only] <install directory>
EOF
  exit $exitcode
}

maybeRustVersion=
installDir=
buildVariant=release
maybeReleaseFlag=--release
validatorOnly=

while [[ -n $1 ]]; do
  if [[ ${1:0:1} = - ]]; then
    if [[ $1 = --debug ]]; then
      maybeReleaseFlag=
      buildVariant=debug
      shift
    elif [[ $1 = --validator-only ]]; then
      validatorOnly=true
      shift
    else
      usage "Unknown option: $1"
    fi
  elif [[ ${1:0:1} = \+ ]]; then
    maybeRustVersion=$1
    shift
  else
    installDir=$1
    shift
  fi
done

if [[ -z "$installDir" ]]; then
  usage "Install directory not specified"
  exit 1
fi

installDir="$(mkdir -p "$installDir"; cd "$installDir"; pwd)"
mkdir -p "$installDir/bin/deps"

echo "Install location: $installDir ($buildVariant)"

cd "$(dirname "$0")"/..

SECONDS=0

if [[ $CI_OS_NAME = windows ]]; then
  # Limit windows to end-user command-line tools.  Full validator support is not
  # yet available on windows
  BINS=(
    cargo-build-bpf
    cargo-build-sbf
    cargo-test-bpf
    cargo-test-sbf
    sonoma
    sonoma-keygen
    sonoma-stake-accounts
    solana-test-validator
    sonoma-tokens
  )
else
  ./fetch-perf-libs.sh

  BINS=(
    sonoma
    sonoma-bench-tps
    sonoma-faucet
    sonoma-gossip
    sonoma-keygen
    sonoma-ledger-tool
    sonoma-log-analyzer
    sonoma-net-shaper
    sonoma-sys-tuner
    solana-validator
    rbpf-cli
  )

  # Speed up net.sh deploys by excluding unused binaries
  if [[ -z "$validatorOnly" ]]; then
    BINS+=(
      cargo-build-bpf
      cargo-build-sbf
      cargo-test-bpf
      cargo-test-sbf
      sonoma-dos
      sonoma-stake-accounts
      solana-test-validator
      sonoma-tokens
      sonoma-watchtower
    )
  fi

  #XXX: Ensure `solana-genesis` is built LAST!
  # See https://github.com/solana-labs/solana/issues/5826
  BINS+=(sonoma-genesis)
fi

binArgs=()
for bin in "${BINS[@]}"; do
  binArgs+=(--bin "$bin")
done

mkdir -p "$installDir/bin"

(
  set -x
  # shellcheck disable=SC2086 # Don't want to double quote $rust_version
  "$cargo" $maybeRustVersion build $maybeReleaseFlag "${binArgs[@]}"

  # Exclude `spl-token` binary for net.sh builds
  if [[ -z "$validatorOnly" ]]; then
    # shellcheck disable=SC2086 # Don't want to double quote $rust_version
    "$cargo" $maybeRustVersion install --locked spl-token-cli --version 2.3.0 --root "$installDir"
  fi
)

for bin in "${BINS[@]}"; do
  cp -fv "target/$buildVariant/$bin" "$installDir"/bin
done

# Rename validator and test-validator bins
mv "$installDir/bin/solana-validator" "$installDir/bin/sonoma-validator"
mv "$installDir/bin/solana-test-validator" "$installDir/bin/sonoma-test-validator"

if [[ -d target/perf-libs ]]; then
  cp -a target/perf-libs "$installDir"/bin/perf-libs
fi

if [[ -z "$validatorOnly" ]]; then
  # shellcheck disable=SC2086 # Don't want to double quote $rust_version
  "$cargo" $maybeRustVersion build --manifest-path programs/bpf_loader/gen-syscall-list/Cargo.toml
  # shellcheck disable=SC2086 # Don't want to double quote $rust_version
  "$cargo" $maybeRustVersion run --bin gen-headers
  mkdir -p "$installDir"/bin/sdk/bpf
  cp -a sdk/bpf/* "$installDir"/bin/sdk/bpf
fi

(
  set -x
  # deps dir can be empty
  shopt -s nullglob
  for dep in target/"$buildVariant"/deps/libsolana*program.*; do
    cp -fv "$dep" "$installDir/bin/deps"
  done
)

echo "Done after $SECONDS seconds"
echo
echo "To use these binaries:"
echo "  export PATH=\"$installDir\"/bin:\"\$PATH\""
