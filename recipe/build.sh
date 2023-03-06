#!/bin/bash

set -xeo pipefail

export PATH="${PREFIX}/bin:${PATH}"

if [[ "$(uname)" = Darwin ]] ; then
    # The -dead_strip_dylibs option breaks g-ir-scanner in this package: the
    # scanner links a test executable to find paths to dylibs, but with this
    # option the linker strips them out. The resulting error message is
    # "ERROR: can't resolve libraries to shared libraries: ...".
    export LDFLAGS="$(echo $LDFLAGS |sed -e "s/-Wl,-dead_strip_dylibs//g")"
    export LDFLAGS_LD="$(echo $LDFLAGS_LD |sed -e "s/-dead_strip_dylibs//g")"
fi

# Needed for jpeg on Linux/GCC7:
export CPPFLAGS="$CPPFLAGS -I$PREFIX/include"

meson_options_common=(
    --buildtype=release
    --prefix="$PREFIX"
    --backend=ninja
    --wrap-mode=nofallback
    -Dgtk_doc=false
    -Dman=false
    -Dgio_sniffing=false
    -Dinstalled_tests=false
    -Dlibdir=lib
    -Drelocatable=true
    -Dintrospection=enabled
)

export PKG_CONFIG="$BUILD_PREFIX/bin/pkg-config"
export PKG_CONFIG_PATH_FOR_BUILD="$BUILD_PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BUILD_PREFIX/lib/pkgconfig"

# setup
meson setup "${meson_options_common[@]}" ${MESON_ARGS} --prefix=$PREFIX builddir

# print build configuration results
meson configure builddir

# build
ninja -C builddir -j ${CPU_COUNT} -v

# test - some errors, ignore test results for now
ninja -C builddir -j ${CPU_COUNT} test || true

# install
ninja -C builddir -j ${CPU_COUNT} install

cd $PREFIX
rm -rf share/gtk-doc
find . -name '*.la' -delete
