#!/bin/bash
# This script installs all external dependencies

checkLastSuccess() {
  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    echo "Install Error: $1"
    exit 1
  fi
}

# install cmake
cmake_version=3.14
CMAKE=$(cmake --version | grep ${cmake_version})
if [ -z "$CMAKE" ]; then	
  cd ~/temp/cmake &&	
    ./bootstrap && make -j4 && make install	
  checkLastSuccess "install cmake ${cmake_version} fails"	
else
  echo "cmake ${cmake_version} has been installed, skip"
fi
# install grpc and related components
# 1. install cares
CARES=$(find /usr -name '*c-ares*')
if [ -z "$CARES" ]; then
  cd ~/temp/grpc/third_party/cares/cares &&
    CXX=g++-9 CC=gcc-9 cmake -DCMAKE_BUILD_TYPE=Debug &&
    make && make install
  checkLastSuccess "install c-ares fails"
else
  echo "c-ares has been installed, skip"
fi
# 2. install protobuf
protobuf_version="3.6"
PROTOBUF=$(protoc --version | grep ${protobuf_version})
if [ -z "$PROTOBUF" ]; then
  cd ~/temp/grpc/third_party/protobuf/cmake &&
    mkdir -p build && cd build &&
    # use cmake instead of autogen.sh so that protobuf-config.cmake can be installed
    CXX=g++-9 CC=gcc-9 cmake -Dprotobuf_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Debug .. &&
    make && make install && make clean && ldconfig
  checkLastSuccess "install protobuf ${protobuf_version} fails"
else
  echo "protobuf ${protobuf_version} has been installed, skip"
fi
# 3. install grpc
# install libssl-dev to skip installing boringssl
grpc_version="1.16"
GRPC=$(grep ${grpc_version} /usr/local/lib/cmake/grpc/gRPCConfigVersion.cmake)
if [ -z "$GRPC" ]; then
  cd ~/temp/grpc &&
    sed -i -E "s/(gRPC_ZLIB_PROVIDER.*)module(.*CACHE)/\1package\2/" CMakeLists.txt &&
    sed -i -E "s/(gRPC_CARES_PROVIDER.*)module(.*CACHE)/\1package\2/" CMakeLists.txt &&
    sed -i -E "s/(gRPC_SSL_PROVIDER.*)module(.*CACHE)/\1package\2/" CMakeLists.txt &&
    sed -i -E "s/(gRPC_PROTOBUF_PROVIDER.*)module(.*CACHE)/\1package\2/" CMakeLists.txt &&
    echo "src/core/lib/gpr/log_linux.cc,src/core/lib/gpr/log_posix.cc,src/core/lib/iomgr/ev_epollex_linux.cc" | tr "," "\n" | xargs -L1 sed -i "s/gettid/sys_gettid/" &&
    CXX=g++-9 CC=gcc-9 cmake -DCMAKE_BUILD_TYPE=Debug &&
    make && make install && make clean && ldconfig
  checkLastSuccess "install grpc ${grpc_version} fails"
else
  echo "gRPC ${grpc_version} has been installed, skip"
fi
# install rocksdb
rocksdb_version="6.5.2"
ROCKSDB=$(find /usr -name '*librocksdb*')	
if [ -z "$ROCKSDB" ]; then	
  cd ~/temp/rocksdb &&
    # enable portable due to https://github.com/benesch/cockroach/commit/0e5614d54aa9a11904f59e6316cfabe47f46ce02	
    export PORTABLE=1 && export FORCE_SSE42=1 && export CXX=g++-9 && export CC=gcc-9 &&	
    make static_lib &&	
    make install-static
  checkLastSuccess "install rocksdb ${rocksdb_version} fails"
else	
  echo "RocksDB ${rocksdb_version} has been installed, skip"	
fi
# give read access to cmake modules
chmod o+rx -R /usr/local/lib/cmake
chmod o+rx -R /usr/local/include/
# link python
ln -s /usr/bin/python2 /usr/bin/python
pip2 install gcovr
