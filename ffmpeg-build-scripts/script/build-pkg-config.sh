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

# load functions
. $SCRIPT_DIR/functions.sh

if isMsys; then
    SYSTEM_PKG_CONFIG="$(command -v pkg-config 2> /dev/null || command -v pkgconf 2> /dev/null)"
    if [ -z "$SYSTEM_PKG_CONFIG" ]; then
        echo "pkg-config/pkgconf was not found in PATH; install it via MSYS2 packages"
        exit 1
    fi

    mkdir -p "$TOOL_DIR/bin"
    checkStatus $? "create tool bin directory failed"

    ln -sf "$SYSTEM_PKG_CONFIG" "$TOOL_DIR/bin/pkg-config"
    checkStatus $? "link pkg-config failed"

    echo "use Windows pkg-config from $SYSTEM_PKG_CONFIG"
    "$TOOL_DIR/bin/pkg-config" --version
    checkStatus $? "run pkg-config failed"
    exit 0
fi

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/pkg-config")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "pkg-config"
checkStatus $? "create directory failed"
cd "pkg-config/"
checkStatus $? "change directory failed"

# download source
download https://pkg-config.freedesktop.org/releases/pkg-config-$VERSION.tar.gz "pkg-config.tar.gz"
checkStatus $? "download of pkg-config failed"

# unpack
tar -zxf "pkg-config.tar.gz"
checkStatus $? "unpack pkg-config failed"
cd "pkg-config-$VERSION/"
checkStatus $? "change directory failed"

# windows specific stuff
DETECTED_OS="$(uname -o 2> /dev/null)"
echo "detected OS: $DETECTED_OS"
if [ $DETECTED_OS = "Msys" ]; then
    # pkg-config 0.29.2 vendors an older GLib snapshot that uses "bool" as a
    # struct field name; GCC in newer MSYS2 toolchains treats bool as a keyword.
    appendFlag CFLAGS "-std=gnu17"
    appendFlag CXXFLAGS "-std=gnu++17"

    # download patches
    # https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-pkg-config
    echo "download patches for windows"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch "1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch"
    checkStatus "download of patch 1001 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1003-g_abort.all.patch "1003-g_abort.all.patch"
    checkStatus "download of patch 1003 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch "1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch"
    checkStatus "download of patch 1005 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1017-glib-use-gnu-print-scanf.patch "1017-glib-use-gnu-print-scanf.patch"
    checkStatus "download of patch 1017 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1024-return-actually-written-data-in-printf.all.patch "1024-return-actually-written-data-in-printf.all.patch"
    checkStatus "download of patch 1024 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1030-fix-stat.all.patch "1030-fix-stat.all.patch"
    checkStatus "download of patch 1030 failed"
    download https://raw.githubusercontent.com/msys2/MINGW-packages/5e72f0204a19fd0a45d50d8e08bf9bed6455b32b/mingw-w64-pkg-config/1031-fix-glib-gettext-m4-error.patch "1031-fix-glib-gettext-m4-error.patch"
    checkStatus "download of patch 1031 failed"

    # patch fixes for windows build
    cd glib
    echo "apply patches for windows"
    patch -Np1 -i "../1001-Use-CreateFile-on-Win32-to-make-sure-g_unlink-always.patch"
    checkStatus "apply patch 1001 failed"
    patch -Np1 -i "../1003-g_abort.all.patch"
    checkStatus "apply patch 1003 failed"
    patch -Np1 -i "../1005-glib-send-log-messages-to-correct-stdout-and-stderr.patch"
    checkStatus "apply patch 1005 failed"
    patch -Np1 -i "../1017-glib-use-gnu-print-scanf.patch"
    checkStatus "apply patch 1017 failed"
    patch -Np1 -i "../1024-return-actually-written-data-in-printf.all.patch"
    checkStatus "apply patch 1024 failed"
    patch -Np1 -i "../1030-fix-stat.all.patch"
    checkStatus "apply patch 1030 failed"
    patch -Np1 -i "../1031-fix-glib-gettext-m4-error.patch"
    checkStatus "apply patch 1031 failed"
    cd ..
fi

# build fix for macOS (glib)
# https://gitlab.com/martinr92/ffmpeg/-/issues/27
if [ $DETECTED_OS = "Darwin" ]; then
    appendFlag CFLAGS "-Wno-int-conversion"
fi

# prepare build
./configure --prefix="$TOOL_DIR" --with-pc-path="$TOOL_DIR/lib/pkgconfig" --with-internal-glib
checkStatus $? "configuration of pkg-config failed"

# build
make
checkStatus $? "build of pkg-config failed"

# install
make install
checkStatus $? "installation of pkg-config failed"
