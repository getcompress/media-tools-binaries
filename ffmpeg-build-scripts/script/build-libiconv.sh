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
LOG_DIR=$(dirname "$SOURCE_DIR")/log

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/libiconv")
checkStatus $? "load version failed"
echo "version: $VERSION"

if isMsys; then
    if [ -n "${MINGW_PREFIX:-}" ]; then
        SYSTEM_PREFIX="$MINGW_PREFIX"
    else
        SYSTEM_CC="$(command -v gcc 2> /dev/null || command -v clang 2> /dev/null || true)"
        if [ -z "$SYSTEM_CC" ]; then
            echo "no suitable compiler found to detect MSYS2 prefix"
            exit 1
        fi
        SYSTEM_PREFIX="$(dirname "$(dirname "$SYSTEM_CC")")"
    fi

    echo "stage static libiconv from $SYSTEM_PREFIX"

    command -v pacman >/dev/null
    checkStatus $? "pacman is required to identify MSYS2 libiconv package"
    PACMAN_OWNER=$(pacman -Qo "$SYSTEM_PREFIX/lib/libiconv.a")
    checkStatus $? "identify MSYS2 libiconv package failed"
    LIBICONV_PACKAGE=$(printf '%s\n' "$PACMAN_OWNER" | sed -E 's/^.* is owned by ([^ ]+) ([^ ]+)$/\1/')
    LIBICONV_PACKAGE_VERSION=$(printf '%s\n' "$PACMAN_OWNER" | sed -E 's/^.* is owned by ([^ ]+) ([^ ]+)$/\2/')
    LIBICONV_UPSTREAM_VERSION=${LIBICONV_PACKAGE_VERSION%-*}
    if [ -z "$LIBICONV_PACKAGE" ] || [ -z "$LIBICONV_PACKAGE_VERSION" ] || [ -z "$LIBICONV_UPSTREAM_VERSION" ] || [ "$LIBICONV_PACKAGE" = "$PACMAN_OWNER" ]; then
        echo "failed to parse MSYS2 libiconv package owner: $PACMAN_OWNER"
        exit 1
    fi

    echo "MSYS2 libiconv package: $LIBICONV_PACKAGE $LIBICONV_PACKAGE_VERSION"

    for REQUIRED_FILE in \
        "$SYSTEM_PREFIX/include/iconv.h" \
        "$SYSTEM_PREFIX/include/libcharset.h" \
        "$SYSTEM_PREFIX/include/localcharset.h" \
        "$SYSTEM_PREFIX/lib/libiconv.a" \
        "$SYSTEM_PREFIX/lib/libcharset.a" \
        "$SYSTEM_PREFIX/lib/pkgconfig/iconv.pc" \
        "$SYSTEM_PREFIX/share/licenses/libiconv/COPYING.LIB" \
        "$SYSTEM_PREFIX/share/licenses/libiconv/README" \
        "$SYSTEM_PREFIX/share/licenses/libiconv/libcharset/COPYING.LIB"
    do
        if [ ! -f "$REQUIRED_FILE" ]; then
            echo "missing required MSYS2 libiconv file: $REQUIRED_FILE"
            if [ -d "$SYSTEM_PREFIX/share/licenses/libiconv" ]; then
                echo "MSYS2 libiconv license directory contents:"
                find "$SYSTEM_PREFIX/share/licenses/libiconv" -maxdepth 3 -type f -print | sort
            fi
            exit 1
        fi
    done

    mkdir -p "$TOOL_DIR/include" "$TOOL_DIR/lib/pkgconfig"
    checkStatus $? "create libiconv tool directories failed"
    cp "$SYSTEM_PREFIX/include/iconv.h" "$TOOL_DIR/include/iconv.h"
    checkStatus $? "copy iconv.h failed"
    cp "$SYSTEM_PREFIX/include/libcharset.h" "$TOOL_DIR/include/libcharset.h"
    checkStatus $? "copy libcharset.h failed"
    cp "$SYSTEM_PREFIX/include/localcharset.h" "$TOOL_DIR/include/localcharset.h"
    checkStatus $? "copy localcharset.h failed"
    cp "$SYSTEM_PREFIX/lib/libiconv.a" "$TOOL_DIR/lib/libiconv.a"
    checkStatus $? "copy libiconv.a failed"
    cp "$SYSTEM_PREFIX/lib/libcharset.a" "$TOOL_DIR/lib/libcharset.a"
    checkStatus $? "copy libcharset.a failed"
    cp "$SYSTEM_PREFIX/lib/pkgconfig/iconv.pc" "$TOOL_DIR/lib/pkgconfig/iconv.pc"
    checkStatus $? "copy iconv.pc failed"

    sed -i.original \
        -e "s|^prefix=.*|prefix=$TOOL_DIR|g" \
        -e 's|^exec_prefix=.*|exec_prefix=${prefix}|g' \
        -e 's|^libdir=.*|libdir=${exec_prefix}/lib|g' \
        -e 's|^includedir=.*|includedir=${prefix}/include|g' \
        "$TOOL_DIR/lib/pkgconfig/iconv.pc"
    checkStatus $? "rewrite iconv.pc failed"

    mkdir -p "$LOG_DIR/libiconv"
    checkStatus $? "create libiconv metadata directory failed"
    printf '%s\n' "$LIBICONV_UPSTREAM_VERSION" > "$LOG_DIR/libiconv/version"
    checkStatus $? "write libiconv version metadata failed"
    printf '%s\n' "$LIBICONV_PACKAGE_VERSION" > "$LOG_DIR/libiconv/package_version"
    checkStatus $? "write libiconv package version metadata failed"
    printf '%s\n' "$LIBICONV_PACKAGE" > "$LOG_DIR/libiconv/package_name"
    checkStatus $? "write libiconv package name metadata failed"

    LIBICONV_SOURCE_DIR="$SOURCE_DIR/libiconv/libiconv-$LIBICONV_UPSTREAM_VERSION"
    mkdir -p "$LIBICONV_SOURCE_DIR/libcharset"
    checkStatus $? "create libiconv license source directory failed"
    cp "$SYSTEM_PREFIX/share/licenses/libiconv/COPYING.LIB" "$LIBICONV_SOURCE_DIR/COPYING.LIB"
    checkStatus $? "copy libiconv COPYING.LIB failed"
    cp "$SYSTEM_PREFIX/share/licenses/libiconv/README" "$LIBICONV_SOURCE_DIR/README"
    checkStatus $? "copy libiconv README failed"
    cp "$SYSTEM_PREFIX/share/licenses/libiconv/libcharset/COPYING.LIB" "$LIBICONV_SOURCE_DIR/libcharset/COPYING.LIB"
    checkStatus $? "copy libcharset COPYING.LIB failed"

    FORBIDDEN_FILES=$(find "$TOOL_DIR" \
        \( -name 'libiconv.dll.a' -o -name 'libcharset.dll.a' -o -name 'libiconv-2.dll' -o -name 'libcharset-1.dll' \) \
        -print)
    checkStatus $? "scan staged libiconv files failed"
    if [ -n "$FORBIDDEN_FILES" ]; then
        echo "ERROR: staged libiconv contains dynamic artifacts"
        echo "$FORBIDDEN_FILES"
        exit 1
    fi

    exit 0
fi

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "libiconv"
checkStatus $? "create directory failed"
cd "libiconv/"
checkStatus $? "change directory failed"

# download source
download https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$VERSION.tar.gz "libiconv.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "libiconv.tar.gz"
checkStatus $? "unpack failed"
cd "libiconv-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
./configure --prefix="$TOOL_DIR" --enable-static=yes
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
