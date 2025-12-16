#!/bin/bash
export VCPKG_ROOT=$(pwd)/vcpkg
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build