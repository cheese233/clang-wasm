#!/bin/bash

TOP_LEVEL=$(dirname $0)
TOP_LEVEL=$(realpath "$TOP_LEVEL")

LLVM_SRC=$TOP_LEVEL/llvm-project
LLVM_BUILD=$TOP_LEVEL/build
LLVM_NATIVE=$TOP_LEVEL/build-native

if [ ! -d $LLVM_SRC/ ]; then 
    git clone https://github.com/llvm/llvm-project --depth=1 "$LLVM_SRC" --branch "llvmorg-15.0.7" --single-branch

    pushd $LLVM_SRC
    git apply $TOP_LEVEL/llvm-project.patch
    popd
fi

if [ ! -d $LLVM_NATIVE/ ]; then
    cmake -G Ninja \
        -S $LLVM_SRC/llvm/ \
        -B $LLVM_NATIVE/ \
        -D CMAKE_C_COMPILER_LAUNCHER=ccache -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD=WebAssembly \
        -DLLVM_ENABLE_PROJECTS="lld;clang"
fi
cmake --build $LLVM_NATIVE -- llvm-tblgen clang-tblgen
if [ "$1" == "clangd" ]; then
    CXXFLAGS="-Dwait4=__syscall_wait4 -pthread" \
    LDFLAGS="\
        -s LLD_REPORT_UNDEFINED=1 \
        -s ALLOW_MEMORY_GROWTH=1 \
        -s EXPORTED_FUNCTIONS=_main,_free,_malloc \
        -s EXPORTED_RUNTIME_METHODS=FS,ERRNO_CODES,allocateUTF8 \
        -pthread \
        -s MODULARIZE \
        -s EXPORT_NAME="createClangdModule" \
        -s ASYNCIFY \
        -s ENVIRONMENT=web,worker \
    " emcmake cmake -G Ninja \
        -S $LLVM_SRC/llvm/ \
        -B $LLVM_BUILD/ \
        -D CMAKE_C_COMPILER_LAUNCHER=ccache -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="" \
        -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
        -DLLVM_ENABLE_DUMP=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_ENABLE_THREADS=ON \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
        -DLLVM_TABLEGEN=$LLVM_NATIVE/bin/llvm-tblgen \
        -DCLANG_TABLEGEN=$LLVM_NATIVE/bin/clang-tblgen
    
    cmake --build $LLVM_BUILD --target clangd
elif [ "$1" == "clang" ]; then
    CXXFLAGS="-Dwait4=__syscall_wait4 -pthread" \
    LDFLAGS="\
        -s LLD_REPORT_UNDEFINED=1 \
        -s ALLOW_MEMORY_GROWTH=1 \
        -s EXPORTED_FUNCTIONS=_main,_free,_malloc \
        -s EXPORTED_RUNTIME_METHODS=FS,ERRNO_CODES,allocateUTF8 \
        -pthread \
        -s MODULARIZE \
        -s EXPORT_NAME="createClangModule" \
        -s ASYNCIFY \
        -s ENVIRONMENT=web,worker \
    " emcmake cmake -G Ninja \
        -S $LLVM_SRC/llvm/ \
        -B $LLVM_BUILD/ \
        -D CMAKE_C_COMPILER_LAUNCHER=ccache -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_TARGETS_TO_BUILD="" \
        -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
        -DLLVM_ENABLE_DUMP=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_ENABLE_THREADS=ON \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
        -DLLVM_TABLEGEN=$LLVM_NATIVE/bin/llvm-tblgen \
        -DCLANG_TABLEGEN=$LLVM_NATIVE/bin/clang-tblgen
    
    cmake --build $LLVM_BUILD --target clang
fi

rm -rf pkg/dist
mkdir pkg/dist
cp build/bin/* pkg/dist
