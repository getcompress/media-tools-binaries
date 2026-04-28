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

# $1 = script directory
# $2 = working directory
# $3 = tool directory
# $4 = CPUs

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/openh264")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openh264"
checkStatus $? "create directory failed"
cd "openh264/"
checkStatus $? "change directory failed"

# download source
download https://github.com/cisco/openh264/archive/v$VERSION.tar.gz "openh264.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openh264.tar.gz"
checkStatus $? "unpack failed"
cd "openh264-$VERSION/"
checkStatus $? "change directory failed"

# The openh264 Makefile has no platform file for Windows ARM (mingw_ntarm).
# openh264 2.6.0 also has no CMakeLists.txt, so cmake is not an option either.
# Use the meson build system, which openh264 provides and which is portable.
# uname -m on MSYS2 reflects the POSIX layer (x86_64) even on native ARM64
# hardware, so detect the CLANGARM64 subsystem via $MSYSTEM.
if isMsys && [ "${MSYSTEM:-}" = "CLANGARM64" ]; then
    prepareMeson
    meson setup \
        --buildtype release \
        --prefix "$TOOL_DIR" \
        --libdir lib \
        --default-library static \
        openh264_build
    checkStatus $? "meson configuration failed"
    ninja -v -j "$CPUS" -C openh264_build
    checkStatus $? "build failed"
    ninja -v -C openh264_build install
    checkStatus $? "installation failed"

    # The Meson install path on Windows ARM does not consistently leave a
    # pkg-config file where FFmpeg expects it. Generate one explicitly so
    # `pkg-config --static openh264` works during the FFmpeg configure step.
    # FFmpeg probes external libraries with the C compiler, so the static C++
    # runtime dependencies also need to be declared in the .pc file.
    mkdir -p "$TOOL_DIR/lib/pkgconfig"
    cat > "$TOOL_DIR/lib/pkgconfig/openh264.pc" << PCEOF
prefix=$TOOL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: openh264
Description: OpenH264 codec library
Version: ${VERSION}
Libs: -L\${libdir} -lopenh264
Libs.private: -lc++ -lc++abi -lunwind
Cflags: -I\${includedir}
PCEOF
    checkStatus $? "create openh264.pc failed"
else
    # build
    make PREFIX="$TOOL_DIR" -j $CPUS
    checkStatus $? "build failed"

    # install
    make install-static PREFIX="$TOOL_DIR"
    checkStatus $? "installation failed"
fi

verifyToolPkgConfigModule "$TOOL_DIR" openh264
checkStatus $? "openh264 pkg-config validation failed"

OPENH264_CC="$(command -v gcc 2> /dev/null || command -v clang 2> /dev/null)"
if [ -z "$OPENH264_CC" ]; then
    echo "no suitable compiler found for openh264 pkg-config probe"
    exit 1
fi

OPENH264_TEST_DIR=$(mktemp -d 2> /dev/null || mktemp -d -t openh264-pc-test)
cat > "$OPENH264_TEST_DIR/openh264-test.c" <<'EOF'
#include <wels/codec_api.h>

int main(void) {
    OpenH264Version version = WelsGetCodecVersion();
    return version.uMajor == 0 && version.uMinor == 0;
}
EOF
PKG_CONFIG_BIN="${TOOL_DIR}/bin/pkg-config"
PKG_CONFIG_LIBDIR="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/share/pkgconfig" \
    "$OPENH264_CC" \
    $("$PKG_CONFIG_BIN" --cflags openh264) \
    "$OPENH264_TEST_DIR/openh264-test.c" \
    -o "$OPENH264_TEST_DIR/openh264-test.exe" \
    $("$PKG_CONFIG_BIN" --libs --static openh264)
checkStatus $? "openh264 compile probe failed"
