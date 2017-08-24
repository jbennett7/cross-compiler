# From: http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/
function FAIL {
  echo "${1}"
  exit 1
}

BASE=`pwd`
SOURCES=${BASE}/sources
[ ! -d ${SOURCES} ] && mkdir -p ${SOURCES}
TARGET=${BASE}/target
[ ! -d ${TARGET} ] && mkdir -p ${TARGET}
BUILD=${BASE}/build
[ ! -d ${BUILD} ] && mkdir -p ${BUILD}

# This shows how to build a cross-compiler for AArch64 processors.
BUILD_TARGET='aarch64-linux'

cd ${SOURCES}
# wget-list
wget http://ftpmirror.gnu.org/binutils/binutils-2.24.tar.gz
wget http://ftpmirror.gnu.org/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.17.2.tar.xz
wget http://ftpmirror.gnu.org/glibc/glibc-2.20.tar.xz
wget http://ftpmirror.gnu.org/mpfr/mpfr-3.1.2.tar.xz
wget http://ftpmirror.gnu.org/gmp/gmp-6.0.0a.tar.xz
wget http://ftpmirror.gnu.org/mpc/mpc-1.0.2.tar.gz
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.12.2.tar.bz2
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.1.tar.gz

# Extract to a sources files to BUILD.
cd ${BUILD}
tar xvf ${SOURCES}/*.tar*

# Setup the GCC directory.
cd ${BUILD}/gcc-4.9.2
for p in mpfr gmp mpc isl cloog;do
    ln -s ../${p}-* ${p}
done

# Set up a path
PATH=${TARGET}/bin:${PATH}

mkdir ${BUILD}/build-binutils
cd ${BUILD}/build-binutils
../binutils-2.24/configure \
    --prefix=${TARGET} \
    --target=${BUILD_TARGET} \
    --disable-multilib
make -j4 2> make.error.log &&
make install || FAIL "binutils build failed."

cd ${BUILD}/linux-3.17.2
make ARCH=arm64 INSTALL_HDR_PATH=${TARGET}/aarch64-linux headers_install

mkdir -p ${BUILD}/build-gcc
cd ${BUILD}/build-gcc
../gcc-4.9.2/configure \
    --prefix=${TARGET} \
    --target=${BUILD_TARGET} \
    --enable-languages=c,c++ \
    --disable-multilib
make -j4 all-gcc 2> make.error.log &&
make install-gcc || FAIL "gcc build failed."

mkdir -p ${BUILD}/build-glibc
cd ${BUILD}/build-glibc
../glibc-2.20/configure \
    --prefix=${TARGET} \
    --target=${BUILD_TARGET} \
    --build=${MACHTYPE} \
    --host=aarch-linux \
    --with-headers=${TARGET}/aarch64-linux/include \
    --disable-multilib \
    libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers 2> make.error.log && 
echo "FIRST MAKE PASSED" >> make.error.log &&
make -j4 csu/subdir_lib 2>> make.error.log &&
install csu/crrl.o csu/crti.o csu/crtn.o ${TARGET}/aarch64-linux/lib &&
aarch64-linux-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o ${TARGET}/aarch64-linux/lib/libc.so &&
touch ${TARGET}/aarch64-linux/include/gnu/stubs.h || FAIL "Building glibc library failed."

cd ${BUILD}/build-gcc
make -j4 2> make.error.log &&
make install || FAIL "Rebuilding gcc after building glibc failed."
