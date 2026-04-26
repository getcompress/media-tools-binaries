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

checkStatus(){
    if [ $1 -ne 0 ]
    then
        echo "check failed: $2"
        exit 1
    fi
}

echoSection(){
    echo ""
    echo "$1"
}

currentTimeInSeconds(){
    TIME_GDATE=$(date +%s)
    if [ $? -eq 0 ]
    then
        echo $TIME_GDATE
    else
        echo 0
    fi
}

echoDurationInSections(){
    END_TIME=$(currentTimeInSeconds)
    echo "took $(($END_TIME - $1))s"
}

download(){
    URL=$1
    NAME=$2
    curl -o "$NAME" -L -f "$URL"
}

appendFlag(){
    VAR_NAME=$1
    FLAG=$2
    eval "CURRENT_VALUE=\${$VAR_NAME}"
    if [ -n "$CURRENT_VALUE" ]; then
        eval "$VAR_NAME=\"\$CURRENT_VALUE \$FLAG\""
    else
        eval "$VAR_NAME=\"\$FLAG\""
    fi
    export "$VAR_NAME"
}

isMsys(){
    [ "$(uname -o 2> /dev/null)" = "Msys" ]
}

applyTargetEnv(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    appendFlag LDFLAGS "-Wl,-search_paths_first"

    if [ -n "$TARGET_ARCH" ]; then
        appendFlag CFLAGS "-arch $TARGET_ARCH"
        appendFlag CXXFLAGS "-arch $TARGET_ARCH"
        appendFlag OBJCFLAGS "-arch $TARGET_ARCH"
        appendFlag OBJCXXFLAGS "-arch $TARGET_ARCH"
        appendFlag LDFLAGS "-arch $TARGET_ARCH"
    fi

    if [ -n "$MACOSX_DEPLOYMENT_TARGET" ]; then
        appendFlag CFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag CXXFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag OBJCFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag OBJCXXFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        appendFlag LDFLAGS "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
        export MACOSX_DEPLOYMENT_TARGET
    fi
}

cmakeTargetArgs(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ -n "$TARGET_ARCH" ]; then
        printf '%s ' "-DCMAKE_OSX_ARCHITECTURES=$TARGET_ARCH"
    fi
    if [ -n "$MACOSX_DEPLOYMENT_TARGET" ]; then
        printf '%s ' "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
    fi
}

cmakePolicyCompatArgs(){
    command -v cmake > /dev/null 2>&1 || return
    CMAKE_MAJOR_VERSION=$(cmake --version | head -n 1 | sed -n 's/[^0-9]*\([0-9]\+\)\..*/\1/p')

    case "$CMAKE_MAJOR_VERSION" in
        ''|*[!0-9]*)
            return
            ;;
    esac

    if [ "$CMAKE_MAJOR_VERSION" -ge 4 ]; then
        # SRT 1.5.4 declares a pre-3.5 CMake minimum; this lets CMake 4 accept it.
        printf '%s ' "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    fi
}

cmakeBuild(){
    cmake --build . --parallel "$1"
}

cmakeInstall(){
    cmake --install .
}

useToolPkgConfig(){
    TOOL_DIR=$1

    export PKG_CONFIG="${TOOL_DIR}/bin/pkg-config"
    export PKG_CONFIG_LIBDIR="${TOOL_DIR}/lib/pkgconfig:${TOOL_DIR}/share/pkgconfig"
    unset PKG_CONFIG_PATH

    export CMAKE_PREFIX_PATH="$TOOL_DIR"
}

pruneToolDynamicLibraries(){
    TOOL_DIR=$1

    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ ! -d "${TOOL_DIR}/lib" ]; then
        return
    fi

    find "${TOOL_DIR}/lib" -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.so.*" \) -print -exec rm -f {} \;
}

pruneHomebrewDynamicLibraries(){
    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ "$ALLOW_PRUNE_HOMEBREW_DYLIBS" != "YES" ]; then
        echo "skip Homebrew dylib pruning"
        return
    fi

    for BREW_OPT_DIR in /usr/local/opt /opt/homebrew/opt
    do
        if [ ! -d "$BREW_OPT_DIR" ]; then
            continue
        fi

        for FORMULA in gettext libpng xz libx11
        do
            if [ ! -d "$BREW_OPT_DIR/$FORMULA/lib" ]; then
                continue
            fi

            find -L "$BREW_OPT_DIR/$FORMULA/lib" -maxdepth 1 -name "*.dylib" \( -type f -o -type l \) -print | while IFS= read -r DYLIB
            do
                DYLIB_DIR=$(dirname "$DYLIB")
                DYLIB_NAME=$(basename "$DYLIB")
                STATIC_ARCHIVE="${DYLIB_DIR}/${DYLIB_NAME%%.*}.a"

                if [ -f "$STATIC_ARCHIVE" ]; then
                    echo "$DYLIB"
                    rm -f "$DYLIB"
                else
                    echo "keep $DYLIB; no matching static archive at $STATIC_ARCHIVE"
                fi
            done
        done
    done

    for BREW_LIB_DIR in /usr/local/lib /opt/homebrew/lib
    do
        if [ ! -d "$BREW_LIB_DIR" ]; then
            continue
        fi

        find "$BREW_LIB_DIR" -maxdepth 1 \( \
            -name "libintl*.dylib" -o \
            -name "libpng*.dylib" -o \
            -name "liblzma*.dylib" -o \
            -name "libX11*.dylib" \
        \) \( -type f -o -type l \) -print | while IFS= read -r DYLIB
        do
            DYLIB_DIR=$(dirname "$DYLIB")
            DYLIB_NAME=$(basename "$DYLIB")
            STATIC_ARCHIVE="${DYLIB_DIR}/${DYLIB_NAME%%.*}.a"

            if [ -f "$STATIC_ARCHIVE" ]; then
                echo "$DYLIB"
                rm -f "$DYLIB"
            else
                echo "keep $DYLIB; no matching static archive at $STATIC_ARCHIVE"
            fi
        done
    done
}

validateToolLinkageMetadata(){
    TOOL_DIR=$1

    if [ "$(uname)" != "Darwin" ]; then
        return
    fi

    if [ ! -d "$TOOL_DIR" ]; then
        return
    fi

    HOST_LINKAGE_MATCHES=$(
        find "$TOOL_DIR" -type f \( -name "*.pc" -o -name "*.la" \) \
            -exec grep -nE '(/usr/local/opt|/opt/homebrew/opt|/usr/local/Cellar|/opt/homebrew/Cellar|\.dylib)' {} + 2> /dev/null
    )

    if [ -n "$HOST_LINKAGE_MATCHES" ]; then
        echo "tool metadata contains host-specific or dynamic linkage:"
        echo "$HOST_LINKAGE_MATCHES"
        return 1
    fi
}

findConfigAuxFile(){
    FILE_NAME=$1

    for CANDIDATE in \
        /usr/share/automake*/$FILE_NAME \
        /usr/share/libtool/build-aux/$FILE_NAME \
        /opt/homebrew/Cellar/libtool/*/share/libtool/build-aux/$FILE_NAME \
        /usr/local/Cellar/libtool/*/share/libtool/build-aux/$FILE_NAME
    do
        if [ -f "$CANDIDATE" ]; then
            echo "$CANDIDATE"
            return 0
        fi
    done

    return 1
}

refreshConfigAuxFiles(){
    TARGET_DIR=$1

    CONFIG_GUESS_SOURCE=$(findConfigAuxFile "config.guess")
    checkStatus $? "find config.guess failed"
    CONFIG_SUB_SOURCE=$(findConfigAuxFile "config.sub")
    checkStatus $? "find config.sub failed"

    cp "$CONFIG_GUESS_SOURCE" "$TARGET_DIR/config.guess"
    checkStatus $? "copy config.guess failed"
    cp "$CONFIG_SUB_SOURCE" "$TARGET_DIR/config.sub"
    checkStatus $? "copy config.sub failed"
    chmod +x "$TARGET_DIR/config.guess" "$TARGET_DIR/config.sub"
    checkStatus $? "chmod config.guess/config.sub failed"
}

prepareMeson(){
    python3 -m virtualenv .venv
    if [ $? -ne 0 ]; then
        echo "python virtualenv module not available, try built-in venv"
        python3 -m venv .venv
    fi

    if [ $? -ne 0 ]; then
        echo "python create virtual environment failed"

        # check, if meson is natively available
        MESON_VERSION=$(meson -v 2> /dev/null)
        checkStatus $? "meson was also not found: please install python correctly with virtualenv"
        echo "using meson $MESON_VERSION"
    else
        . .venv/bin/activate
        checkStatus $? "python activate virtual environment failed"
        pip install meson
        checkStatus $? "python meson installation failed"
    fi
}
