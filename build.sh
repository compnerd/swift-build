#!/bin/bash
# Copyright 2021 Saleem Abdulrasool <compnerd@compnerd.org>

SourceCache=/SourceCache
BinaryCache=/BinaryCache
ToolchainInstallRoot=/Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain
PlatformInstallRoot=/Library/Developer/Platforms/Linux.platform
SDKInstallRoot="${PlatformInstallRoot}/Developer/SDKs/Linux.sdk"

set -e

# zlib
cmake                                                                           \
  -B "${BinaryCache}/zlib-1.2.11"                                               \
  -D BUILD_SHARED_LIBS=NO                                                       \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX=/Library/zlib-1.2.11/usr                              \
  -D SKIP_INSTALL_FILES=YES                                                     \
  -G Ninja                                                                      \
  -S "${SourceCache}/zlib"
cmake --build "${BinaryCache}/zlib-1.2.11"
cmake --build "${BinaryCache}/zlib-1.2.11" --target install

# libxml2
cmake                                                                           \
  -B "${BinaryCache}/libxml2"                                                   \
  -D BUILD_SHARED_LIBS=NO                                                       \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX=/Library/libxml2-2.9.12/usr                           \
  -D LIBXML2_WITH_ICONV=NO                                                      \
  -D LIBXML2_WITH_ICU=NO                                                        \
  -D LIBXML2_WITH_LZMA=NO                                                       \
  -D LIBXML2_WITH_PYTHON=NO                                                     \
  -D LIBXML2_WITH_TESTS=NO                                                      \
  -D LIBXML2_WITH_THREADS=YES                                                   \
  -D LIBXML2_WITH_ZLIB=NO                                                       \
  -G Ninja                                                                      \
  -S "${SourceCache}/libxml2"
cmake --build "${BinaryCache}/libxml2-2.9.12"
cmake --build "${BinaryCache}/libxml2-2.9.12" --target install

# curl
cmake                                                                           \
  -B "${BinaryCache}/curl-7.77.0"                                               \
  -D BUILD_SHARED_LIBS=NO                                                       \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX=/Library/curl-7.77.0/usr                              \
  -D BUILD_CURL_EXE=NO                                                          \
  -D CMAKE_USE_OPENSSL=YES                                                      \
  -D CURL_CA_PATH=none                                                          \
  -D CMAKE_USE_SCHANNEL=NO                                                      \
  -D CMAKE_USE_LIBSSH2=NO                                                       \
  -D HAVE_POLL_FINE=NO                                                          \
  -D CURL_DISABLE_LDAP=YES                                                      \
  -D CURL_DISABLE_LDAPS=YES                                                     \
  -D CURL_DISABLE_TELNET=YES                                                    \
  -D CURL_DISABLE_DICT=YES                                                      \
  -D CURL_DISABLE_FILE=YES                                                      \
  -D CURL_DISABLE_TFTP=YES                                                      \
  -D CURL_DISABLE_RTSP=YES                                                      \
  -D CURL_DISABLE_PROXY=YES                                                     \
  -D CURL_DISABLE_POP3=YES                                                      \
  -D CURL_DISABLE_IMAP=YES                                                      \
  -D CURL_DISABLE_SMTP=YES                                                      \
  -D CURL_DISABLE_GOPHER=YES                                                    \
  -D CURL_ZLIB=YES                                                              \
  -D ENABLE_UNIX_SOCKETS=NO                                                     \
  -D ENABLE_THREADED_RESOLVER=NO                                                \
  -D ZLIB_ROOT=/Library/zlib-1.2.11/usr                                         \
  -D ZLIB_LIBRARY=/Library/zlib-1.2.11/usr/lib/libzlibstatic.a                  \
  -G Ninja                                                                      \
  -S "${SourceCache}/curl"
cmake --build "${BinaryCache}/curl-7.77.0"
cmake --build "${BinaryCache}/curl-7.77.0" --target install

# ICU
[[ -f "${SourceCache}/icu/icu4c/CMakeLists.txt" ]] || cp -v "${SourceCache}/swift-build/cmake/ICU/CMakeLists69.txt" "${SourceCache}/icu/icu4c/CMakeLists.txt"

cmake                                                                           \
  -B "${BinaryCache}/icu-69.1"                                                  \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX=/Library/icu-69.1/usr                                 \
  -D BUILD_TOOLS=YES                                                            \
  -G Ninja                                                                      \
  -S "${SourceCache}/icu/icu4c"
cmake --build "${BinaryCache}/icu-69.1"
cmake --build "${BinaryCache}/icu-69.1" --target install

# sqlite
[[ -f /var/cache/sqlite-amalgamation-3360000.zip ]] || curl -sL https://sqlite.org/2021/sqlite-amalgamation-3360000.zip -o /var/cache/sqlite-amalgamation-3360000.zip

if [[ ! -d "${SourceCache}/sqlite-3.36.0" ]] ; then
  mkdir -p "${SourceCache}/sqlite-3.36.0"
  unzip -j -o /var/cache/sqlite-amalgamation-3360000.zip -d "${SourceCache}/sqlite-3.36.0"
  cp -v "${SourceCache}/swift-build/cmake/SQLite/CMakeLists.txt" "${SourceCache}/sqlite-3.36.0"
fi

cmake                                                                           \
  -B "${BinaryCache}/sqlite-3.36.0"                                             \
  -D BUILD_SHARED_LIBS=NO                                                       \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX=/Library/sqlite-3.36.0/usr                            \
  -G Ninja                                                                      \
  -S "${SourceCache}/sqlite-3.36.0"
cmake --build "${BinaryCache}/sqlite-3.36.0"
cmake --build "${BinaryCache}/sqlite-3.36.0" --target install

# toolchain
cmake                                                                           \
  -B "${BinaryCache}/toolchain"                                                 \
  -C "${SourceCache}/swift/cmake/caches/Linux-x86_64.cmake"                     \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D LLVM_EXTERNAL_CMARK_SOURCE_DIR="${SourceCache}/cmark"                      \
  -D LLVM_EXTERNAL_SWIFT_SOURCE_DIR="${SourceCache}/swift"                      \
  -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  \
  -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES                   \
  -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES                                  \
  -D SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=YES                            \
  -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=${SourceCache}\swift-corelibs-libdispatch \
  -D SWIFT_LINUX_x86_64_ICU_I18N=/Library/icu-69.1/usr/lib/libicuin69.so        \
  -D SWIFT_LINUX_x86_64_ICU_I18N_INCLUDE=/Library/icu-69.1/usr/include          \
  -D SWIFT_LINUX_x86_64_ICU_UC=/Library/icu-69.1/usr/lib/libicuuc69.so          \
  -D SWIFT_LINUX_x86_64_ICU_UC_INCLUDE=/Library/icu-69.1/usr/include            \
  -G Ninja                                                                      \
  -S "${SourceCache}\llvm-project\llvm"
cmake --build "${BinaryCache}/llvm-project/llvm"
cmake --build "${BinaryCache}/llvm-project/llvm" --target install

# Restructure Internal Modules
for module in _InternalSwiftScan _InternalSwiftSyntaxParser ; do
  if [[ -d "${ToolchainInstallRoot}/usr/include/${module}" ]] ; then
    rm -rf "${ToolchainInstallRoot}/usr/include/${module}"
  fi
  mv -v "${ToolchainInstallRoot}/usr/lib/${module}" "${ToolchainInstallRoot}/usr/include"
  mv -v "${ToolchainInstallRoot}/usr/lib/swift/linux/lib${module}.a" "${ToolchainInstallRoot}/usr/lib"
done

# Runtime
cmake                                                                           \
  -B "${BinaryCache}/runtime-llvm"                                              \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D LLVM_HOST_TRIPLE=x86_64-unknown-linux-gnu                                  \
  -G Ninja                                                                      \
  -S "${SourceCache}/llvm-project/llvm"

cmake                                                                           \
  -B "${BinaryCache}/runtime"                                                   \
  -C "${SourceCache}/swift/cmake/caches/Runtime-Linux-x86_64.cmake"             \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D LLVM_DIR="${BinaryCache}/runtime-llvm/lib/cmake/llvm"                      \
  -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES                                  \
  -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES                   \
  -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES                                  \
  -D SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=YES                            \
  -D SWIFT_NATIVE_SWIFT_TOOLS_PATH="${BinaryCache}/toolchain/bin"               \
  -D SWIFT_LINUX_x86_64_ICU_I18N=/Library/icu-69.1/usr/lib/libicuin69.a         \
  -D SWIFT_LINUX_x86_64_ICU_I18N_INCLUDE=/Library/icu-69.1/usr/include          \
  -D SWIFT_LINUX_x86_64_ICU_UC=/Library/icu-69.1/usr/lib/libicuuc69.a           \
  -D SWIFT_LINUX_x86_64_ICU_UC_INCLUDE=\Library/icu-69.1/usr/include            \
  -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=${SourceCache}/swift-corelibs-libdispatch \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift"
cmake --build "${BinaryCache}/runtime"
cmake --build "${BinaryCache}/runtime" --target install

for module in _Concurrency _Differentiation _Distributed, Swift, SwiftOnoneSupport ; do
  if [[ -d "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule" ]]
  then
    rm -rf "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule"
  fi
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/${module}.swiftmodule" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/"
done

# swift-corelibs-libdispatch
cmake                                                                           \
  -B "${BinaryCache}/swift-corelibs-libdispatch"                                \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D BUILD_TESTING=NO                                                           \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${SDKInstallRoot}/usr"                               \
  -D ENABLE_SWIFT=YES                                                           \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-corelibs-libdispatch"
cmake --build "${BinaryCache}/swift-corelibs-libdispatch"

# clean up any existing install
if [[ -d "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule" ]] ; then
  rm -rf "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule"
fi

cmake --build "${BinaryCache}/swift-corelibs-libdispatch" --target install

# Restructure BlocksRuntime, dispatch headers
for module in Block dispatch os ; do
  rm -rf "${SDKInstallRoot}/usr/include/${module}"
  mv -v "${SDKInstallRoot}/usr/lib/swift/${module}" "${SDKInstallRoot}/usr/include"
done

# Restructure Libraries
for module in BlocksRuntime dispatch swiftDispatch ; do
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/lib${module}.so" "${SDKInstallRoot}/usr/lib"
done

# Restructure Module
mv -v "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/_.swiftmodule"
mkdir "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule"
mv "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/_.swiftmodule" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule/x86_64-unknown-linux-gnu.swiftmodule"
mv "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftdoc" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/Dispatch.swiftmodule/x86_64-unknown-linux-gnu.swiftdoc"

# swift-corelibs-foundation
cmake                                                                           \
  -B "${BinaryCache}/swift-corelibs-foundation"                                 \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${SDKInstallRoot}/usr"                               \
  -D CURL_DIR=/Library/curl-7.77.0/usr/lib/cmake/CURL                           \
  -D ICU_I18N_LIBRARY_RELEASE=/Library/icu-69.1/usr/lib/libicuin69.so           \
  -D ICU_ROOT=/Library/icu-69.1/usr                                             \
  -D LIBXML2_LIBRARY=/Library/libxml2-2.9.12/usr/lib/libxml2s.a                 \
  -D LIBXML2_INCLUDE_DIR=/Library/libxml2-2.9.12/usr/include/libxml2            \
  -D LIBXML2_DEFINITIONS="-DLIBXML_STATIC"                                      \
  -D ZLIB_LIBRARY=/Library/zlib-1.2.11/usr/lib/libzlibstatic.a                  \
  -D ZLIB_INCLUDE_DIR=/Library/zlib-1.2.11/usr/include                          \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D ENABLE_TESTING=NO                                                          \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-corelibs-foundation"
cmake --build "${BinaryCache}/swift-corelibs-foundation"

# Clean up any existing installation
for module in Foundation FoundationNetworking FoundationXML ; do
  if [[ -d "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule" ]]
  then
    rm -rf "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule"
  fi
done

cmake --build "${BinaryCache}/swift-corelibs-foundation" --target install

# Restructure CoreFoundation Headers
for module in CoreFoundation CFXMLInterface CFURLSessioninterface ; do
  mv "${SDKInstallRoot}/usr/lib/swift/${module}" "${SDKInstallRoot}/usr/include"
done

# Restructure Libraries, Modules
for module in Foundation FoundationNetworking FoundationXML ; do
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/lib${module}.so" "${SDKInstallRoot}/usr/lib"
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/_.swiftmodule"
  mkdir "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule"
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/_.swiftmodule" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule/x86_64-unknown-linux-gnu.swiftmodule"
  mv -v "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftdoc" "${SDKInstallRoot}/usr/lib/swift/linux/x86_64/${module}.swiftmodule/x86_64-unknown-linux-gnu.swiftdoc"
done

# swift-corelibs-xctest
cmake                                                                           \
  -B "${BinaryCache}/swift-corelibs-xctest"                                     \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${PlatformInstallRoot}/Developer/Library/XCTest-development/usr" \
  -D CURL_DIR=/Library/curl-7.77.0/usr/lib/cmake/CURL                           \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-corelibs-xctest"
cmake --build "${BinaryCache}/swift-corelibs-xctest"
cmake --build "${BinaryCache}/swift-corelibs-xctest" --target install

# swift-tools-support-core
cmake                                                                           \
  -B "${BinaryCache}/swift-tools-support-core"                                  \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D SQLite3_INCLUDE_DIR=/Library/sqlite-3.36.0/usr/include                     \
  -D SQLite3_LIBRARY=/Library/sqlite-3.36.0/usr/lib/libSQLite3.a                \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-tools-support-core"
cmake --build "${BinaryCache}/swift-tools-support-core"
cmake --build "${BinaryCache}/swift-tools-support-core" --target install

# llbuild
cmake                                                                           \
  -B "${BinaryCache}/llbuild"                                                   \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D LLBUILD_SUPPORT_BINDINGS=Swift                                             \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D SQLite3_INCLUDE_DIR=/Library/sqlite-3.36.0/usr/include                     \
  -D SQLite3_LIBRARY=/Library/sqlite-3.36.0/usr/lib/libSQLite3.a                \
  -G Ninja                                                                      \
  -S "${SourceCache}/llbuild"
cmake --build "${BinaryCache}/llbuild"
cmake --build "${BinaryCache}/llbuild" --target install

# Yams
cmake                                                                           \
  -B "${BinaryCache}/Yams"                                                      \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D XCTest_DIR="${BinaryCache}/swift-corelibs-xctest/cmake/modules"            \
  -G Ninja                                                                      \
  -S "${SourceCache}/Yams"
cmake --build "${BinaryCache}/Yams"
cmake --build "${BinaryCache}/Yams" --target install

# swift-argument-parser
cmake                                                                           \
  -B "${BinaryCache}/swift-argument-parser"                                     \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D BUILD_TESTING=NO                                                           \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D XCTest_DIR="${BinaryCache}/swift-corelibs-xctest/cmake/modules"            \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-argument-parser"
cmake --build "${BinaryCache}/swift-argument-parser"
cmake --build "${BinaryCache}/swift-argument-parser" --target install

# swift-driver
cmake                                                                           \
  -B "${BinaryCache}/swift-driver"                                              \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D BUILD_TESTING=NO                                                           \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D TSC_DIR="${BinaryCache}/swift-tools-support-core/cmake/modules"            \
  -D LLBuild_DIR="${BinaryCache}/llbuild/cmake/modules"                         \
  -D Yams_DIR="${BinaryCache}/Yams/cmake/modules"                               \
  -D ArgumentParser_DIR="${BinaryCache}/swift-argument-parser/cmake/modules"    \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-argument-parser"
cmake --build "${BinaryCache}/swift-driver"
cmake --build "${BinaryCache}/swift-driver" --target install

# swift-crypto
cmake                                                                           \
  -B "${BinaryCache}/swift-crypto"                                              \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-crypto"
cmake --build "${BinaryCache}/swift-crypto"
cmake --build "${BinaryCache}/swift-crypto" --target install

# swift-collections
cmake                                                                           \
  -B "${BinaryCache}/swift-collections"                                         \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-collections"
cmake --build "${BinaryCache}/swift-collections"
cmake --build "${BinaryCache}/swift-collections" --target install

# swift-package-manager
cmake                                                                           \
  -B "${BinaryCache}/swift-package-manager"                                     \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D TSC_DIR="${BinaryCache}/swift-tools-support-core/cmake/modules"            \
  -D LLBuild_DIR="${BinaryCache}/llbuild/cmake/modules"                         \
  -D ArgumentParser_DIR="${BinaryCache}/swift-argument-parser/cmake/modules"    \
  -D SwiftDriver_DIR="${BinaryCache}/swift-driver/cmake/modules"                \
  -D SwiftCrypto_DIR="${BinaryCache}/swift-crypto/cmake/modules"                \
  -D SwiftCollections_DIR="${BinaryCache}/swift-collections/cmake/modules"      \
  -G Ninja                                                                      \
  -S "${SourceCache}/swift-package-manager"
cmake --build "${BinaryCache}/swift-package-manager"
cmake --build "${BinaryCache}/swift-package-manager" --target install

# indexstore-db
cmake                                                                           \
  -B "${BinaryCache}/indexstore-db"                                             \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -G Ninja                                                                      \
  -S "${SourceCache}/indexstore-db"
cmake --build "${BinaryCache}/indexstore-db"
cmake --build "${BinaryCache}/indexstore-db" --target install

# sourcekit-lsp
cmake                                                                           \
  -B "${BinaryCache}/sourcekit-lsp"                                             \
  -D BUILD_SHARED_LIBS=YES                                                      \
  -D CMAKE_BUILD_TYPE=Release                                                   \
  -D CMAKE_C_COMPILER="${BinaryCache}/toolchain/bin/clang"                      \
  -D CMAKE_CXX_COMPILER="${BinaryCache}/toolchain/bin/clang++"                  \
  -D CMAKE_Swift_COMPILER="${BinaryCache}/toolchain/bin/swiftc"                 \
  -D CMAKE_INSTALL_PREFIX="${ToolchainInstallRoot}/usr"                         \
  -D dispatch_DIR="${BinaryCache}/swift-corelibs-libdispatch/cmake/modules"     \
  -D Foundation_DIR="${BinaryCache}/swift-corelibs-foundation/cmake/modules"    \
  -D TSC_DIR="${BinaryCache}/swift-tools-support-core/cmake/modules"            \
  -D LLBuild_DIR="${BinaryCache}/llbuild/cmake/modules"                         \
  -D ArgumentParser_DIR="${BinaryCache}/swift-argument-parser/cmake/modules"    \
  -D SwiftCollections_DIR="${BinaryCache}/swift-collections/cmake/modules"      \
  -D SwiftPM_DIR="${BinaryCache}/swift-package-manager/cmake/modules"           \
  -D IndexStoreDB_DIR="${BinaryCache}/indexstore-db/cmake/modules"              \
  -G Ninja                                                                      \
  -S "${SourceCache}/sourcekit-lsp"
cmake --build "${BinaryCache}/sourcekit-lsp"
cmake --build "${BinaryCache}/sourcekit-lsp" --target install
