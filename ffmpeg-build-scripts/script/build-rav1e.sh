#!/bin/sh

# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This file is part of the GetCompress media-tools-binaries repository and is
# distributed under the GNU Affero General Public License, version 3 or any
# later version.
#
# It is derived from Martin Riedl's FFmpeg build script project:
# https://git.martin-riedl.de/ffmpeg/build-script.git
#
# Upstream attribution and the Apache-2.0 license text are preserved in this
# repository for upstream-origin material. See NOTICE and
# ffmpeg-build-scripts/LICENSE for details.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/rav1e")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "rav1e"
checkStatus $? "create directory failed"
cd "rav1e/"
checkStatus $? "change directory failed"

# download source
download https://github.com/xiph/rav1e/archive/refs/tags/v$VERSION.tar.gz "rav1e.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "rav1e.tar.gz"
checkStatus $? "unpack failed"
cd "rav1e-$VERSION/"
checkStatus $? "change directory failed"

# rav1e depends on libz-sys. On Windows, force that crate to use our prebuilt
# zlib via pkg-config instead of falling back to bundled C code, because the
# GitHub-hosted Rust toolchains are MSVC-hosted while these builds target GNU
# Windows environments under MSYS2.
if isMsys; then
    export LIBZ_SYS_USE_PKG_CONFIG=1
    export LIBZ_SYS_STATIC=1
    export PKG_CONFIG_ALL_STATIC=1
    export PKG_CONFIG_ALLOW_CROSS=1

    case "${RUST_TARGET:-}" in
        x86_64-pc-windows-gnu)
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=gcc
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR=ar
            export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-static-libgcc -C link-arg=-static-libstdc++"
            export CC_x86_64_pc_windows_gnu=gcc
            export AR_x86_64_pc_windows_gnu=ar
            ;;
        aarch64-pc-windows-gnullvm)
            export CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_LINKER=clang
            export CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_AR=llvm-ar
            export CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_RUSTFLAGS="-C target-feature=+crt-static"
            export CC_aarch64_pc_windows_gnullvm=clang
            export AR_aarch64_pc_windows_gnullvm=llvm-ar
            ;;
    esac
fi

# install
if isMsys && [ -n "$RUST_TARGET" ]; then
    cargo cinstall --library-type staticlib --release -j $CPUS --target "$RUST_TARGET" --prefix "$TOOL_DIR" --libdir="$TOOL_DIR/lib"
else
    cargo cinstall --library-type staticlib --release -j $CPUS --prefix "$TOOL_DIR" --libdir="$TOOL_DIR/lib"
fi
checkStatus $? "build or installation failed"
