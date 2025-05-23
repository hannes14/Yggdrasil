# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "Fontconfig"
version = v"2.16.0"

# Collection of sources required to build FriBidi
sources = [
    ArchiveSource("https://www.freedesktop.org/software/fontconfig/release/fontconfig-$(version).tar.xz",
                  "6a33dc555cc9ba8b10caf7695878ef134eeb36d0af366041f639b1da9b6ed220"),
    DirectorySource("bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/fontconfig-*

FLAGS=()
if [[ "${target}" == *-linux-* ]] || [[ "${target}" == *-freebsd* ]]; then
    FLAGS+=(--with-add-fonts="/usr/local/share/fonts")
    if [[ "${target}" == *-linux-* ]]; then
        FLAGS+=(--with-cache-dir="/var/cache/fontconfig")
    elif [[ "${target}" == *-freebsd* ]]; then
        FLAGS+=(--with-cache-dir="/var/db/fontconfig")
    fi
elif [[ "${target}" == *-apple-* ]]; then
    FLAGS+=(--with-add-fonts="/System/Library/Fonts,/Library/Fonts,~/Library/Fonts,/System/Library/Assets/com_apple_MobileAsset_Font4,/System/Library/Assets/com_apple_MobileAsset_Font5")
fi

# Apply MinGW patches: https://github.com/msys2/MINGW-packages/tree/33f847297fe429d145cd9d72cb1fbbc574431cc5/mingw-w64-fontconfig
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/0002-fix-mkdir.mingw.patch"
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/0004-fix-mkdtemp.mingw.patch"
atomic_patch -p1 "${WORKSPACE}/srcdir/patches/0005-fix-setenv.mingw.patch"
autoreconf
./configure --prefix=$prefix --build=${MACHTYPE} --host=$target --disable-docs "${FLAGS[@]}"

# Disable tests
sed -i 's,all-am: Makefile $(PROGRAMS),all-am:,' test/Makefile

make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# The products that we will ensure are always built
products = [
    LibraryProduct("libfontconfig", :libfontconfig),
    ExecutableProduct("fc-cache", :fc_cache),
    ExecutableProduct("fc-cat", :fc_cat),
    ExecutableProduct("fc-conflist", :fc_conflist),
    ExecutableProduct("fc-list", :fc_list),
    ExecutableProduct("fc-match", :fc_match),
    ExecutableProduct("fc-pattern", :fc_pattern),
    ExecutableProduct("fc-query", :fc_query),
    ExecutableProduct("fc-scan", :fc_scan),
    ExecutableProduct("fc-validate", :fc_validate),
    FileProduct("etc/fonts/fonts.conf", :fonts_conf),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    HostBuildDependency("gperf_jll"),
    Dependency("FreeType2_jll"; compat="2.13.4"),
    Dependency("Bzip2_jll"; compat="1.0.9"),
    Dependency("Zlib_jll"; compat="1.2.12"),
    Dependency("Libuuid_jll"; compat="2.41.0"),
    Dependency("Expat_jll"; compat="2.6.5"),
]

# @giordano: "I know this looks funky, but it makes code in the JLL indented correctly"
init_block = """
get!(ENV, "FONTCONFIG_FILE", fonts_conf)
    get!(ENV, "FONTCONFIG_PATH", dirname(ENV["FONTCONFIG_FILE"]))
"""

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               init_block=init_block, julia_compat="1.6", preferred_gcc_version=v"6")
