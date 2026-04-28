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
VERSION=$(cat "$SCRIPT_DIR/../version/openjpeg")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "openjpeg"
checkStatus $? "create directory failed"
cd "openjpeg/"
checkStatus $? "change directory failed"

# download source
download https://github.com/uclouvain/openjpeg/archive/refs/tags/v$VERSION.tar.gz "openjpeg.tar.gz"
checkStatus $? "download failed"

# unpack
tar -zxf "openjpeg.tar.gz"
checkStatus $? "unpack failed"

# prepare build
mkdir openjpeg_build
checkStatus $? "create build directory failed"
cd openjpeg_build
checkStatus $? "change build directory failed"
cmake $(cmakeTargetArgs) $(cmakePolicyCompatArgs) \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$TOOL_DIR \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_CODEC=OFF \
    -DBUILD_JPIP=OFF \
    -DBUILD_JPIP_SERVER=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_VIEWER=OFF \
    -DBUILD_MJ2=OFF \
    -DBUILD_JPWL=OFF \
    -DBUILD_DOC=OFF \
    -DBUILD_TESTING=OFF \
    -Wno-dev \
    ../openjpeg-$VERSION/
checkStatus $? "configuration failed"

# build
cmakeBuild "$CPUS"
checkStatus $? "build failed"

# install
cmakeInstall
checkStatus $? "installation failed"

# post-installation
# Windows OpenJPEG installs have proven unreliable in their pkg-config
# metadata. Replace the .pc file with a known-good one so FFmpeg's pkg-config
# probe gets the exact include/lib paths we intend.
if isMsys; then
    mkdir -p "$TOOL_DIR/lib/pkgconfig"
    OPENJPEG_SERIES=$(printf '%s' "$VERSION" | awk -F. '{print $1 "." $2}')
    cat > "$TOOL_DIR/lib/pkgconfig/libopenjp2.pc" << PCEOF
prefix=$TOOL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/openjpeg-${OPENJPEG_SERIES}

Name: openjp2
Description: OpenJPEG library
Version: ${VERSION}
Libs: -L\${libdir} -lopenjp2
Cflags: -I\${includedir} -DOPJ_STATIC
PCEOF
    checkStatus $? "write libopenjp2.pc failed"
fi

# pthreads is not a separate library on Windows (it's w32threads in the runtime)
if ! isMsys; then
    sed -i.original -e 's/lopenjp2/lopenjp2 -lpthread/g' $TOOL_DIR/lib/pkgconfig/libopenjp2.pc
fi

verifyToolPkgConfigModule "$TOOL_DIR" libopenjp2
checkStatus $? "libopenjp2 pkg-config validation failed"

OPENJPEG_CC="$(command -v gcc 2> /dev/null || command -v clang 2> /dev/null)"
if [ -z "$OPENJPEG_CC" ]; then
    echo "no suitable compiler found for libopenjp2 pkg-config probe"
    exit 1
fi

OPENJPEG_TEST_DIR=$(mktemp -d 2> /dev/null || mktemp -d -t openjpeg-pc-test)
cat > "$OPENJPEG_TEST_DIR/openjpeg-test.c" <<'EOF'
#include <openjpeg.h>

int main(void) {
    return opj_version() == 0;
}
EOF
PKG_CONFIG_BIN="${TOOL_DIR}/bin/pkg-config"
PKG_CONFIG_LIBDIR="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/share/pkgconfig" \
    "$OPENJPEG_CC" \
    $("$PKG_CONFIG_BIN" --cflags libopenjp2) \
    "$OPENJPEG_TEST_DIR/openjpeg-test.c" \
    -o "$OPENJPEG_TEST_DIR/openjpeg-test.exe" \
    $("$PKG_CONFIG_BIN" --libs --static libopenjp2)
checkStatus $? "libopenjp2 compile probe failed"
