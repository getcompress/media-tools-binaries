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
# ffmpeg-macos-linux/LICENSE for details.

# handle arguments
echo "arguments: $@"
SCRIPT_DIR=$1
SOURCE_DIR=$2
TOOL_DIR=$3
CPUS=$4

# load functions
. $SCRIPT_DIR/functions.sh

if isMsys; then
    SYSTEM_OPENSSL_BIN="$(command -v openssl 2> /dev/null)"
    if [ -z "$SYSTEM_OPENSSL_BIN" ]; then
        echo "openssl was not found in PATH; install it via MSYS2 packages"
        exit 1
    fi

    SYSTEM_PREFIX="$(dirname "$(dirname "$SYSTEM_OPENSSL_BIN")")"
    SYSTEM_INCLUDE_DIR="$SYSTEM_PREFIX/include"
    SYSTEM_LIB_DIR="$SYSTEM_PREFIX/lib"
    SYSTEM_PKGCONFIG_DIR="$SYSTEM_LIB_DIR/pkgconfig"

    if [ ! -d "$SYSTEM_INCLUDE_DIR/openssl" ]; then
        echo "openssl headers were not found under $SYSTEM_INCLUDE_DIR"
        exit 1
    fi
    if [ ! -f "$SYSTEM_LIB_DIR/libcrypto.a" ] || [ ! -f "$SYSTEM_LIB_DIR/libssl.a" ]; then
        echo "openssl static libraries were not found under $SYSTEM_LIB_DIR"
        exit 1
    fi

    mkdir -p "$TOOL_DIR/include" "$TOOL_DIR/lib/pkgconfig"
    checkStatus $? "create openssl tool directories failed"

    rm -rf "$TOOL_DIR/include/openssl"
    checkStatus $? "remove stale openssl include directory failed"
    cp -R "$SYSTEM_INCLUDE_DIR/openssl" "$TOOL_DIR/include/"
    checkStatus $? "copy openssl headers failed"

    cp "$SYSTEM_LIB_DIR/libcrypto.a" "$TOOL_DIR/lib/"
    checkStatus $? "copy libcrypto.a failed"
    cp "$SYSTEM_LIB_DIR/libssl.a" "$TOOL_DIR/lib/"
    checkStatus $? "copy libssl.a failed"

    for pc_file in libcrypto.pc libssl.pc openssl.pc
    do
        cp "$SYSTEM_PKGCONFIG_DIR/$pc_file" "$TOOL_DIR/lib/pkgconfig/$pc_file"
        checkStatus $? "copy $pc_file failed"
        sed -i.original -e "s|^prefix=.*|prefix=$TOOL_DIR|g" "$TOOL_DIR/lib/pkgconfig/$pc_file"
        checkStatus $? "rewrite $pc_file prefix failed"
    done

    echo "use Windows OpenSSL from $SYSTEM_PREFIX"
    "$SYSTEM_OPENSSL_BIN" version
    checkStatus $? "run openssl failed"
    exit 0
fi

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/openssl")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openssl"
checkStatus $? "create directory failed"
cd "openssl/"
checkStatus $? "change directory failed"

# download source
download https://github.com/openssl/openssl/releases/download/openssl-$VERSION/openssl-$VERSION.tar.gz "openssl.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openssl.tar.gz"
checkStatus $? "unpack failed"
cd "openssl-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
# use custom lib path, because for any reason on linux amd64 installs otherwise in lib64 instead
./config --prefix="$TOOL_DIR" --openssldir="$TOOL_DIR/openssl" --libdir="$TOOL_DIR/lib" no-shared
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
## install without documentation
make install_sw
checkStatus $? "installation failed (install_sw)"
make install_ssldirs
checkStatus $? "installation failed (install_ssldirs)"
