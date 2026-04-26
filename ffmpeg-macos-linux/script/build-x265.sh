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
SKIP_X265_MULTIBIT=$5

# load functions
. $SCRIPT_DIR/functions.sh

# load version
VERSION=$(cat "$SCRIPT_DIR/../version/x265")
checkStatus $? "load version failed"
echo "version: $VERSION"

# start in working directory
cd "$SOURCE_DIR"
checkStatus $? "change directory failed"
mkdir "x265"
checkStatus $? "create directory failed"
cd "x265/"
checkStatus $? "change directory failed"

# download source
download https://bitbucket.org/multicoreware/x265_git/get/$VERSION.tar.gz "x265.tar.gz"
checkStatus $? "download of x265 failed"

# unpack
mkdir "x265"
checkStatus $? "create directory failed"
tar -zxf "x265.tar.gz" -C x265 --strip-components=1
checkStatus $? "unpack failed"
cd "x265/"
checkStatus $? "change directory failed"

if [ $SKIP_X265_MULTIBIT = "NO" ]; then
    # prepare build 10 bit
    echo "start with 10bit build"
    mkdir 10bit
    checkStatus $? "create directory failed"
    cd 10bit/
    checkStatus $? "change directory failed"
    cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON ../source
    checkStatus $? "configuration 10 bit failed"

    # build 10 bit
    cmakeBuild "$CPUS"
    checkStatus $? "build 10 bit failed"
    cd ..
    checkStatus $? "change directory failed"

    # prepare build 12 bit
    echo "start with 12bit build"
    mkdir 12bit
    checkStatus $? "create directory failed"
    cd 12bit/
    checkStatus $? "change directory failed"
    cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=NO -DENABLE_CLI=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON -DMAIN12=ON ../source
    checkStatus $? "configuration 12 bit failed"

    # build 12 bit
    cmakeBuild "$CPUS"
    checkStatus $? "build 12 bit failed"
    cd ..
    checkStatus $? "change directory failed"

    # prepare build 8 bit
    echo "start with 8bit build"
    ln -s 10bit/libx265.a libx265_10bit.a
    checkStatus $? "symlink creation of 10 bit library failed"
    ln -s 12bit/libx265.a libx265_12bit.a
    checkStatus $? "symlink creation of 12 bit library failed"
    cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=NO -DENABLE_CLI=OFF \
        -DEXTRA_LINK_FLAGS=-L. -DEXTRA_LIB="x265_10bit.a;x265_12bit.a" -DLINKED_10BIT=ON -DLINKED_12BIT=ON source
    checkStatus $? "configuration 8 bit failed"

    # build 8 bit
    cmakeBuild "$CPUS"
    checkStatus $? "build 8 bit failed"

    # merge libraries
    mv libx265.a libx265_8bit.a
    checkStatus $? "move 8 bit library failed"
    if [ "$(uname)" = "Linux" ]; then
    ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_8bit.a
ADDLIB libx265_10bit.a
ADDLIB libx265_12bit.a
SAVE
END
EOF
    else
        libtool -static -o libx265.a libx265_8bit.a libx265_10bit.a libx265_12bit.a
    fi
    checkStatus $? "multi-bit library creation failed"
else
    # prepare build
    cmake $(cmakeTargetArgs) -DCMAKE_INSTALL_PREFIX:PATH=$TOOL_DIR -DENABLE_SHARED=NO -DENABLE_CLI=OFF source
    checkStatus $? "configuration failed"

    # build
    cmakeBuild "$CPUS"
    checkStatus $? "build failed"
fi

# install
cmakeInstall
checkStatus $? "installation failed"

# post-installation
# modify pkg-config file for usage with ffmpeg (it seems that the flag for threads is missing)
# --> https://bitbucket.org/multicoreware/x265_git/issues/371/x265-not-found-using-pkg-config
sed -i.original -e 's/lx265/lx265 -lpthread/g' $TOOL_DIR/lib/pkgconfig/x265.pc
