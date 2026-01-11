#!/bin/bash
set -e

# 1. 强制设定为 arm64
export LWJGL_BUILD_ARCH=arm64
export ANDROID=1 
export LWJGL_BUILD_OFFLINE=1
export LIBFFI_VERSION=3.4.6

# Setup NDK env for arm64
export NDK_ABI=arm64-v8a 
export NDK_TARGET=aarch64
export TARGET=$NDK_TARGET-linux-android
export PATH=$PATH:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin

# 定义 Native 库输出路径
LWJGL_NATIVE=bin/libs/native/linux/$LWJGL_BUILD_ARCH/org/lwjgl
mkdir -p $LWJGL_NATIVE

# 2. 预编译 libffi (LWJGL 核心依赖)
if [ ! -d libffi ]; then
    wget https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz
    tar xvf libffi-$LIBFFI_VERSION.tar.gz
    mv libffi-$LIBFFI_VERSION libffi
fi
cd libffi
# 清理旧的构建
[ -f Makefile ] && make distclean || true
bash configure --host=$TARGET --prefix=$PWD/build_output CC=${TARGET}21-clang CXX=${TARGET}21-clang++
make -j4
cd ..
cp libffi/build_output/lib/libffi.a $LWJGL_NATIVE/

# 3. HACK: 绕过生成器以节省时间 (如果源码已生成)
mkdir -p bin/classes/{generator,templates/META-INF}
touch bin/classes/{generator,templates}/touch.txt bin/classes/generator/generated-touch.txt

# 4. 准备编译器参数
# 针对 NDK 27 (Clang 18) 的语法补丁
FIX_FLAGS="-std=gnu89 -Wno-error -Wno-strict-prototypes -Wno-implicit-const-int-float-conversion -lm"
CC_PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}21-clang
CXX_PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}21-clang++

# 5. 调用 Ant 编译 (只开启核心和 GLES)
ant -Dplatform.linux=true \
  -Dlwjgl.modules=core,egl,opengles \
  -Dbinding.core=true \
  -Dbinding.egl=true \
  -Dbinding.opengles=true \
  -Dbinding.opengl=false \
  -Dbinding.glfw=false \
  -Dbinding.stb=false \
  -Dbinding.assimp=false \
  -Dbinding.bgfx=false \
  -Dbinding.openxr=false \
  -Dbinding.vulkan=false \
  -Dbuild.type=release/3.3.3 \
  -Djavadoc.skip=true \
  -Dcompiler.linux.cc=$CC_PATH \
  -Dcompiler.linux.cxx=$CXX_PATH \
  -Dcompiler.linux.cflags="$FIX_FLAGS" \
  -Dcompiler.linux.linkerflags="$FIX_FLAGS" \
  compile-templates compile compile-native release

# 6. 提取最终产物
rm -rf bin/out; mkdir -p bin/out
echo "正在提取 .so 文件..."
find bin/libs/native -name 'liblwjgl.so' -exec cp {} bin/out/ \;
find bin/libs/native -name 'liblwjgl_opengles.so' -exec cp {} bin/out/ \;

echo "---------------------------------------"
echo "编译完成！产物位于 bin/out/"
ls -lh bin/out/
