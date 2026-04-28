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
VERSION=$(cat "$SCRIPT_DIR/../version/fontconfig")
checkStatus $? "load version failed"
echo "version: $VERSION"

GPERF_BIN="$(command -v gperf 2> /dev/null)"
if [ -z "$GPERF_BIN" ]; then
    echo "gperf is required to build fontconfig but was not found in PATH"
    exit 1
fi
echo "using gperf: $GPERF_BIN"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "fontconfig"
checkStatus $? "create directory failed"
cd "fontconfig/"
checkStatus $? "change directory failed"

# download source
download https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/$VERSION/fontconfig-$VERSION.tar.xz "fontconfig.tar.xz"
checkStatus $? "download failed"

# unpack
tar -xf "fontconfig.tar.xz"
checkStatus $? "unpack failed"
cd "fontconfig-$VERSION/"
checkStatus $? "change directory failed"

# prepare build
appendFlag CPPFLAGS "-I${TOOL_DIR}/include"
appendFlag LDFLAGS "-L${TOOL_DIR}/lib"
./configure --prefix="$TOOL_DIR" --enable-static=yes --enable-shared=no \
    --enable-libxml2 \
    --disable-docs \
    --disable-nls \
    --without-libintl-prefix
checkStatus $? "configuration failed"

# build
make -j $CPUS
checkStatus $? "build failed"

# install
make install
checkStatus $? "installation failed"
