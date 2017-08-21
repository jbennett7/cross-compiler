#!/bin/bash

BASE="$(pwd)"
TARGET='arm-linux-gnueabihf'
PATH=${PATH}:${PREFIX}/bin
PREFIX="${BASE}/target"
SOURCES="${BASE}/sources"
BUILD="${BASE}/build"

[ -d "${SOURCES}" ] || mkdir -p ${SOURCES}
[ -d "${PREFIX}"  ] || mkdir -p ${PREFIX}
[ -d "${BUILD}"   ] || mkdir -p ${BUILD}

function FAIL {
  echo "${1}"
  exit 1
}

function download_sources {
    pushd ${SOURCES}
    for p in $(cat ${BASE}/wget-list);do
        wget ${p}
    done
    popd
}

function build_binutils {
    pushd ${BUILD}
    [ -d ${BUILD}/binutils* ] || tar xvf ${SOURCES}/binutils*.tar.bz2
    [ -d ${BUILD}/build-binutils ] || mkdir ${BUILD}/build-binutils
    pushd ${BUILD}/build-binutils
    ../binutils*/configure --target=${TARGET} --prefix=${PREFIX} &&
    make -j4 all 2> make.error.log &&
    make install || FAIL "FAILED"
    popd
}

# If building on mac OS, this part of the build will throw the following error:
#  ../../gcc-6.3.0/gcc/config/arm/thumb1.md:1615:10873: fatal error: bracket nesting level exceeded maximum of 256.
# SOLUTION:  https://answers.launchpad.net/gcc-arm-embedded/+question/262850
#
# I've searched online, it seems this problem is caused by the clang in OS X. As the clang is not yet fully tested to 
# build this toolchain, I'd suggest you to use gcc instead of clang to build this toolchain. The possible way is:
#    Use Homebrew ( http://brew.sh/ ) to install a gcc.
#    Check the system will use real gcc instaed of clang ( you can use " gcc -v " to check ).
#    Then build the toolchain.
#
function build_gcc_1 {
    pushd ${BUILD}
    [ -d ${BUILD}/gcc* ] || tar xvf ${SOURCES}/gcc*.tar.bz2
    [ -d ${BUILD}/build-gcc ] || mkdir ${BUILD}/build-gcc
    pushd ${BUILD}/build-gcc
    ../gcc*/configure --target=${TARGET} --prefix=${PREFIX} --without-headers --with-newlib --with-gnu-as --with-gnu-ld &&
    make -j4 all-gcc 2> make.error.log &&
    make install-gcc || FAIL "FAILED" 
    popd
}

function build_newlib {
    [ -d ${BUILD}/newlib* ] || tar xvf ${SOURCES}/newlib*.tar.gz
    [ -d ${BUILD}/build-newlib ] || mkdir build-newlib
    pushd ${BUILD}/build-newlib
    ../newlib*/configure --target=${TARGET} --prefix=${PREFIX} &&
    make -j4 all 2> make.error.log &&
    make install || FAIL "FAILED"
    popd
}

function build_gcc_2 {
    pushd ${BUILD}/build-gcc
    ../gcc*/configure --target=${TARGET} --prefix=${PREFIX} --with-newlib --with-gnu-as --with-gnu-ld --disable-shared --disable-libssp &&
    make -j4 all 2> make.error.log &&
    make install || FAIL "FAILED"
    popd
}

function build_gdb {
    [ -d ${BUILD}/gdb* ] || tar xvf ${SOURCES}/gdb*.tar.xz
    [ -d ${BUILD}/build-gdb ] || mkdir ${BUILD}/build-gdb
    pushd ${BUILD}/build-gdb
    ../gdb*/configure --target=${TARGET} --prefix=${PREFIX} &&
    make -j4 all 2> make.error.log &&
    make install || FAIL "FAILED"
    popd
}

case "${1}" in
    download_sources)
        download_sources;;
    build_binutils)
        build_binutils;;
    build_gcc_1)
        build_gcc_1;;
    build_newlib)
        build_newlib;;
    build_gcc_2)
        build_gcc_2;;
    build_gdb)
        build_gdb;;
    build_all)
        build_binutils
        build_gcc_1
        build_newlib
        build_gcc_2
        build_gdb;;
    *)
        grep "function" ${0};;
esac
