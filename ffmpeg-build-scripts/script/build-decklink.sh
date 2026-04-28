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
TOOL_DIR=$2
DECKLINK_SDK=$3

# load functions
. $SCRIPT_DIR/functions.sh

# check decklink folder
cd $DECKLINK_SDK
checkStatus $? "change directory failed"
if [ -f "DeckLinkAPI.h" ]; then
    echo "decklink SDK found"
else
    echo "decklink SDK not found"
    exit 1
fi

# copy SDK
cp * "$TOOL_DIR/include"
checkStatus $? "copy SDK failed"
