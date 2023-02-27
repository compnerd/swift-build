# Copyright 2020 Saleem Abdulrasool <compnerd@compnerd.org>
param(
  [switch] $OnlyX64 = $false
)

Set-StrictMode -Version 3.0

$SourceCache = "S:\SourceCache"
$BinaryCache = "S:\b"
$InstallRoot = "S:\Library"
$ToolchainInstallRoot = "$InstallRoot\Developer\Toolchains\unknown-Asserts-development.xctoolchain"
$PlatformInstallRoot = "$InstallRoot\Developer\Platforms\Windows.platform"
$SDKInstallRoot = "$PlatformInstallRoot\Developer\SDKs\Windows.sdk"

$python = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Shared\Python39_64\python.exe"
$vswhere = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$VSInstallRoot = .$vswhere -nologo -latest -products "*" -all -prerelease -property installationPath
$VsDevShell = "$VSInstallRoot\Common7\Tools\Launch-VsDevShell.ps1"

# Architecture definitions
$ArchX64 = @{ VSName = "amd64"; ShortName = "x64"; LlvmName = "x86_64"; CMakeName = "AMD64"; UsrBinName = "bin64"; BinDirIDBase = 100 }
$ArchX86 = @{ VSName = "x86"; ShortName = "x86"; LlvmName = "i686"; CMakeName = "i686"; UsrBinName = "bin32"; BinDirIDBase = 200 }
$ArchArm64 = @{ VSName = "arm64"; ShortName = "arm64"; LlvmName = "aarch64"; CMakeName = "aarch64"; UsrBinName = "bin64a"; BinDirIDBase = 300 }

# Build functions
function Get-ProjectBuildDir($Arch, $ID)
{
  return "$BinaryCache\" + ($Arch.BinDirIDBase + $ID)
}

function Check-LastExitCode
{
  if ($LastExitCode -ne 0)
  {
    $callstack = @(Get-PSCallStack) -Join "`n"
    throw "Command execution returned $LastExitCode. Call stack:`n$callstack"
  }
}

function Invoke-VsDevShell($Arch)
{
  .$VsDevShell -VsInstallationPath $VSInstallRoot -HostArch amd64 -Arch $Arch.VSName | Out-Null
  Check-LastExitCode
}

function Build-CMakeProject
{
  param
  (
    [string] $B, # Build directory, passed to CMake
    [string] $S, # Source directory, passed to CMake
    [string] $G, # Generator, passed to CMake
    [string[]] $Targets = @() # Targets to build
    # Any other arguments are passed to the CMake generate step as @args
  )

  Write-Host -ForegroundColor Cyan "Building '$S' to '$B' with VS target arch '$env:VSCMD_ARG_TGT_ARCH'..."

  # Generate the project
  cmake -B $B -S $S -G $G @args
  Check-LastExitCode

  # Build all requested targets
  foreach ($Target in $Targets)
  {
    if ($null -eq $Target -or "" -eq $Target)
    {
      cmake --build $B
      Check-LastExitCode
    }
    else
    {
      cmake --build $B --target $Target
      Check-LastExitCode
    }
  }
}

function Build-ToolchainX64
{
  Build-CMakeProject `
    -B $BinaryCache\1 `
    -C $SourceCache\swift\cmake\caches\Windows-x86_64.cmake `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D LLVM_ENABLE_PDB=YES `
    -D LLVM_EXTERNAL_CMARK_SOURCE_DIR=$SourceCache\cmark `
    -D LLVM_EXTERNAL_SWIFT_SOURCE_DIR=$SourceCache\swift `
    -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_REFLECTION=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=YES `
    -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=$SourceCache\swift-corelibs-libdispatch `
    -D SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE=$SourceCache\swift-syntax `
    -D SWIFT_PATH_TO_STRING_PROCESSING_SOURCE=$SourceCache\swift-experimental-string-processing `
    -G Ninja `
    -S $SourceCache\llvm-project\llvm `
    -Targets ("distribution", "install-distribution")

  # Restructure Internal Modules
  Remove-Item -Recurse -Force $ToolchainInstallRoot\usr\include\_InternalSwiftScan -ErrorAction Ignore
  Move-Item -Force $ToolchainInstallRoot\usr\lib\swift\_InternalSwiftScan $ToolchainInstallRoot\usr\include
  Move-Item -Force $ToolchainInstallRoot\usr\lib\swift\windows\_InternalSwiftScan.lib $ToolchainInstallRoot\usr\lib
}

function Build-LlvmX64
{
  $BinDir = Get-ProjectBuildDir $ArchX64 0
  
  Build-CMakeProject `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D LLVM_HOST_TRIPLE=x86_64-unknown-windows-msvc `
    -G Ninja `
    -S $SourceCache\llvm-project\llvm
}

function Build-ZLib($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -B $BinaryCache\zlib-1.2.11.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\zlib-1.2.11\usr `
    -D INSTALL_BIN_DIR=$InstallRoot\zlib-1.2.11\usr\bin\$ArchName `
    -D INSTALL_LIB_DIR=$InstallRoot\zlib-1.2.11\usr\lib\$ArchName `
    -D SKIP_INSTALL_FILES=YES `
    -G Ninja `
    -S $SourceCache\zlib `
    -Targets ($null, "install")
}

function Build-LibXml2($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -B $BinaryCache\libxml2-2.9.12.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\libxml2-2.9.12\usr `
    -D CMAKE_INSTALL_BINDIR=bin/$ArchName `
    -D CMAKE_INSTALL_LIBDIR=lib/$ArchName `
    -D LIBXML2_WITH_ICONV=NO `
    -D LIBXML2_WITH_ICU=NO `
    -D LIBXML2_WITH_LZMA=NO `
    -D LIBXML2_WITH_PYTHON=NO `
    -D LIBXML2_WITH_TESTS=NO `
    -D LIBXML2_WITH_THREADS=YES `
    -D LIBXML2_WITH_ZLIB=NO `
    -G Ninja `
    -S $SourceCache\libxml2 `
    -Targets ($null, "install")
}

function Build-Curl($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -B $BinaryCache\curl-7.77.0.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\curl-7.77.0\usr `
    -D CMAKE_INSTALL_BINDIR=bin/$ArchName `
    -D CMAKE_INSTALL_LIBDIR=lib/$ArchName `
    -D BUILD_CURL_EXE=NO `
    -D CMAKE_USE_OPENSSL=NO `
    -D CURL_CA_PATH=none `
    -D CMAKE_USE_SCHANNEL=YES `
    -D CMAKE_USE_LIBSSH2=NO `
    -D HAVE_POLL_FINE=NO `
    -D CURL_DISABLE_LDAP=YES `
    -D CURL_DISABLE_LDAPS=YES `
    -D CURL_DISABLE_TELNET=YES `
    -D CURL_DISABLE_DICT=YES `
    -D CURL_DISABLE_FILE=YES `
    -D CURL_DISABLE_TFTP=YES `
    -D CURL_DISABLE_RTSP=YES `
    -D CURL_DISABLE_PROXY=YES `
    -D CURL_DISABLE_POP3=YES `
    -D CURL_DISABLE_IMAP=YES `
    -D CURL_DISABLE_SMTP=YES `
    -D CURL_DISABLE_GOPHER=YES `
    -D CURL_ZLIB=YES `
    -D ENABLE_UNIX_SOCKETS=NO `
    -D ENABLE_THREADED_RESOLVER=NO `
    -D ZLIB_ROOT=$InstallRoot\zlib-1.2.11\usr `
    -D ZLIB_LIBRARY=$InstallRoot\zlib-1.2.11\usr\lib\$ArchName\zlibstatic.lib `
    -G Ninja `
    -S $SourceCache\curl `
    -Targets ($null, "install")
}

function Build-Icu($Arch)
{
  $ArchName = $Arch.ShortName

  if (-not(Test-Path -Path "$SourceCache\icu\icu4c\CMakeLists.txt"))
  {
    Copy-Item $SourceCache\swift-installer-scripts\shared\ICU\CMakeLists.txt $SourceCache\icu\icu4c\
    Copy-Item $SourceCache\swift-installer-scripts\shared\ICU\icupkg.inc.cmake $SourceCache\icu\icu4c\
  }

  Build-CMakeProject `
    -B $BinaryCache\icu-69.1.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    -D BUILD_TOOLS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\icu-69.1\usr `
    -D CMAKE_INSTALL_BINDIR=bin/$ArchName `
    -D CMAKE_INSTALL_LIBDIR=lib/$ArchName `
    -G Ninja `
    -S $SourceCache\icu\icu4c `
    -Targets ($null, "install")
}

function Build-SwiftRuntime($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 1
  $ArchShortName = $Arch.ShortName
  $LlvmArch = $Arch.LlvmName

  Build-CMakeProject `
    -B $BinDir `
    -C "$SourceCache\swift\cmake\caches\Runtime-Windows-$LlvmArch.cmake" `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_INSTALL_PREFIX=$SDKInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D LLVM_DIR=$BinaryCache\100\lib\cmake\llvm `
    -D SWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_REFLECTION=YES `
    -D SWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=YES `
    -D SWIFT_NATIVE_SWIFT_TOOLS_PATH=$BinaryCache\1\bin `
    -D SWIFT_PATH_TO_LIBDISPATCH_SOURCE=$SourceCache\swift-corelibs-libdispatch `
    -D SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE=$SourceCache\swift-syntax `
    -D SWIFT_PATH_TO_STRING_PROCESSING_SOURCE=$SourceCache\swift-experimental-string-processing `
    -D SWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE=$SourceCache\swift-syntax `
    -G Ninja `
    -S $SourceCache\swift `
    -Targets ($null, "install")

  # Restructure runtime
  mkdir $InstallRoot\swift-development\usr\bin\$ArchShortName -ErrorAction Ignore
  Move-Item -Force $SDKInstallRoot\usr\bin\*.dll $InstallRoot\swift-development\usr\bin\$ArchShortName\
}

function Build-SwiftCorelibsLibdispatch($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 2
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"
  $LlvmArch = $Arch.LlvmName
  $CMakeArch = $Arch.CMakeName

  Build-CMakeProject `
    -B $BinDir `
    -D BUILD_TESTING=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$CMakeArch `
    -D CMAKE_INSTALL_PREFIX=$SDKInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D ENABLE_SWIFT=YES `
    -G Ninja `
    -S $SourceCache\swift-corelibs-libdispatch `
    -Targets ($null, "install")

  # Restructure Runtime
  Move-Item -Force $SDKInstallRoot\usr\bin\*.dll $InstallRoot\swift-development\usr\bin\x64\

  # Restructure BlocksRuntime, dispatch headers
  foreach ($module in ("Block", "dispatch", "os"))
  {
    Remove-Item -Recurse -Force $SDKInstallRoot\usr\include\$module -ErrorAction Ignore
    Move-Item -Force $SDKInstallRoot\usr\lib\swift\$module $SDKInstallRoot\usr\include\
  }

  # Restructure Import Libraries
  foreach ($module in ("BlocksRuntime", "dispatch", "swiftDispatch"))
  {
    Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$($module).lib $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch
  }

  # Restructure Module
  mkdir $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule -ErrorAction Ignore
  Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch\Dispatch.swiftmodule $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule\$LlvmArch-unknown-windows-msvc.swiftmodule
  Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch\Dispatch.swiftdoc $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule\$LlvmArch-unknown-windows-msvc.swiftdoc
}

function Build-SwiftCorelibsFoundation($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 3
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"
  $DispatchBinDir = Get-ProjectBuildDir $Arch 2
  $ShortArch = $Arch.ShortName
  $LlvmArch = $Arch.LlvmName
  $CMakeArch = $Arch.CMakeName

  Build-CMakeProject `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_ASM_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_ASM_FLAGS="--target=$LlvmArch-unknown-windows-msvc" `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$CMakeArch `
    -D CMAKE_INSTALL_PREFIX=$SDKInstallRoot\usr `
    -D CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL="/MD" `
    -D CMAKE_MT=mt `
    -D CURL_DIR=$InstallRoot\curl-7.77.0\usr\lib\$ShortArch\cmake\CURL `
    -D ICU_DATA_LIBRARY_RELEASE=$InstallRoot\icu-69.1\usr\lib\$ShortArch\sicudt69.lib `
    -D ICU_I18N_LIBRARY_RELEASE=$InstallRoot\icu-69.1\usr\lib\$ShortArch\sicuin69.lib `
    -D ICU_ROOT=$InstallRoot\icu-69.1\usr `
    -D ICU_UC_LIBRARY_RELEASE=$InstallRoot\icu-69.1\usr\lib\$ShortArch\sicuuc69.lib `
    -D LIBXML2_LIBRARY=$InstallRoot\libxml2-2.9.12\usr\lib\$ShortArch\libxml2s.lib `
    -D LIBXML2_INCLUDE_DIR=$InstallRoot\libxml2-2.9.12\usr\include\libxml2 `
    -D LIBXML2_DEFINITIONS="/DLIBXML_STATIC" `
    -D ZLIB_LIBRARY=$InstallRoot\zlib-1.2.11\usr\lib\$ShortArch\zlibstatic.lib `
    -D ZLIB_INCLUDE_DIR=$InstallRoot\zlib-1.2.11\usr\include `
    -D dispatch_DIR=$DispatchBinDir\cmake\modules `
    -D ENABLE_TESTING=NO `
    -G Ninja `
    -S $SourceCache\swift-corelibs-foundation `
    -Targets ($null, "install")

  # Restructure Runtime
  Move-Item -Force $SDKInstallRoot\usr\bin\*.dll $InstallRoot\swift-development\usr\bin\$ShortArch\
  Move-Item -Force $SDKInstallRoot\usr\bin\*.exe $InstallRoot\swift-development\usr\bin\$ShortArch\

  # Remove CoreFoundation Headers
  foreach ($module in ("CoreFoundation", "CFXMLInterface", "CFURLSessionInterface"))
  {
    Remove-Item -Recurse -Force $SDKInstallRoot\usr\lib\swift\$module
  }

  # Restructure Import Libraries, Modules
  foreach ($module in ("Foundation", "FoundationNetworking", "FoundationXML"))
  {
    Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$($module).lib $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch

    mkdir $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule -ErrorAction Ignore
    Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch\$($module).swiftmodule $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule\$LlvmArch-unknown-windows-msvc.swiftmodule
    Move-Item -Force $SDKInstallRoot\usr\lib\swift\windows\$LlvmArch\$($module).swiftdoc $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule\$LlvmArch-unknown-windows-msvc.swiftdoc
  }
}

function Build-SwiftCorelibsXCTest($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 4
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"
  $DispatchBinDir = Get-ProjectBuildDir $Arch 2
  $FoundationBinDir = Get-ProjectBuildDir $Arch 3
  $LlvmArch = $Arch.LlvmName
  $CMakeArch = $Arch.CMakeName
  $UsrBinName = $Arch.UsrBinName

  Build-CMakeProject `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$LlvmArch-unknown-windows-msvc `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$CMakeArch `
    -D CMAKE_INSTALL_PREFIX=$PlatformInstallRoot\Developer\Library\XCTest-development\usr `
    -D dispatch_DIR=$DispatchBinDir\cmake\modules `
    -D Foundation_DIR=$FoundationBinDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-corelibs-xctest `
    -Targets ($null, "install")

  # Restructure Runtime
  Remove-Item -Recurse -Force $PlatformInstallRoot\Developer\Library\XCTest-development\usr\$UsrBinName
  Move-Item $PlatformInstallRoot\Developer\Library\XCTest-development\usr\bin $PlatformInstallRoot\Developer\Library\XCTest-development\usr\$UsrBinName

  # Restructure Import Libraries
  mkdir $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\ -ErorAction Ignore
  Move-Item $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.lib $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.lib

  # Restructure Module
  mkdir $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule -ErorAction Ignore
  Move-Item -Force $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.swiftdoc $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule\$LlvmArch-unknown-windows-msvc.swiftdoc
  Move-Item -Force $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.swiftmodule $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule\$LlvmArch-unknown-windows-msvc.swiftmodule
}

function Build-SqliteX64
{
  $Dest = "$SourceCache\sqlite-3.36.0\"

  # Download the sources
  mkdir "S:\var\cache" -ErrorAction Ignore
  if (-not(Test-Path -Path "S:\var\cache\sqlite-amalgamation-3360000.zip"))
  {
    curl.exe -sL https://sqlite.org/2021/sqlite-amalgamation-3360000.zip -o S:\var\cache\sqlite-amalgamation-3360000.zip
  }

  if (-not(Test-Path -Path $Dest))
  {
    mkdir $Dest -ErrorAction Ignore
    ."$env:ProgramFiles\Git\usr\bin\unzip.exe" -j -o S:\var\cache\sqlite-amalgamation-3360000.zip -d $Dest
    Copy-Item $SourceCache\swift-build\cmake\SQLite\CMakeLists.txt $Dest\
  }

  Build-CMakeProject `
    -B $BinaryCache\sqlite-3.36.0.x64 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\sqlite-3.36.0\usr `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\sqlite-3.36.0 `
    -Targets ($null, "install")
}

function Build-SwiftSystemX64
{
  Build-CMakeProject `
    -B $BinaryCache\2 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\swift-system `
    -Targets ($null, "install")
}

function Build-ToolsSupportCoreX64
{
  Build-CMakeProject `
    -B $BinaryCache\3 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\swift-tools-support-core `
    -Targets ($null, "install")
}

function Build-LLBuildX64
{
  Build-CMakeProject `
    -B $BinaryCache\4 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_CXX_COMPILER=cl `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_CXX_FLAGS="-Xclang -fno-split-cold-code" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D LLBUILD_SUPPORT_BINDINGS=Swift `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\llbuild `
    -Targets ($null, "install")
}

function Build-YamsX64
{
  Build-CMakeProject `
    -B $BinaryCache\5 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D XCTest_DIR=$BinaryCache\104\cmake\modules `
    -G Ninja `
    -S $SourceCache\Yams `
    -Targets ($null)
}

function Build-SwiftArgumentParserX64
{
  Build-CMakeProject `
    -B $BinaryCache\6 `
    -D BUILD_SHARED_LIBS=YES `
    -D BUILD_TESTING=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D XCTest_DIR=$BinaryCache\104\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-argument-parser `
    -Targets ($null, "install")
}

function Build-SwiftDriverX64
{
  Build-CMakeProject `
    -B $BinaryCache\7 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D TSC_DIR=$BinaryCache\3\cmake\modules `
    -D LLBuild_DIR=$BinaryCache\4\cmake\modules `
    -D Yams_DIR=$BinaryCache\5\cmake\modules `
    -D ArgumentParser_DIR=$BinaryCache\6\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\swift-driver `
    -Targets ($null, "install")
}

function Build-SwiftCryptoX64
{
  Build-CMakeProject `
    -B $BinaryCache\8 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-crypto `
    -Targets ($null)
}

function Build-SwiftCollectionsX64
{
  Build-CMakeProject `
    -B $BinaryCache\9 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -G Ninja `
    -S $SourceCache\swift-collections `
    -Targets ($null, "install")
}

function Build-SwiftPackageManagerX64
{
  Build-CMakeProject `
    -B $BinaryCache\10 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-DCRYPTO_v2 -resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D TSC_DIR=$BinaryCache\3\cmake\modules `
    -D LLBuild_DIR=$BinaryCache\4\cmake\modules `
    -D ArgumentParser_DIR=$BinaryCache\6\cmake\modules `
    -D SwiftDriver_DIR=$BinaryCache\7\cmake\modules `
    -D SwiftCrypto_DIR=$BinaryCache\8\cmake\modules `
    -D SwiftCollections_DIR=$BinaryCache\9\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\swift-package-manager `
    -Targets ($null, "install")
}

function Build-IndexStoreDBX64
{
  Build-CMakeProject `
    -B $BinaryCache\11 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_CXX_FLAGS="-Xclang -fno-split-cold-code" `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -G Ninja `
    -S $SourceCache\indexstore-db `
    -Targets ($null)
}

function Build-SwiftSyntaxX64
{
  Build-CMakeProject `
    -B $BinaryCache\12 `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\swift-syntax `
    -Targets ($null, "install")
}

function Build-SourceKitLspX64
{
  Build-CMakeProject `
    -B $BinaryCache\13 `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $BinaryCache\101\lib\swift -L $BinaryCache\101\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$BinaryCache\102\cmake\modules `
    -D Foundation_DIR=$BinaryCache\103\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D TSC_DIR=$BinaryCache\3\cmake\modules `
    -D LLBuild_DIR=$BinaryCache\4\cmake\modules `
    -D ArgumentParser_DIR=$BinaryCache\6\cmake\modules `
    -D SwiftCollections_DIR=$BinaryCache\9\cmake\modules `
    -D SwiftPM_DIR=$BinaryCache\10\cmake\modules `
    -D IndexStoreDB_DIR=$BinaryCache\11\cmake\modules `
    -D SwiftSyntax_DIR=$BinaryCache\12\cmake\modules `
    -G Ninja `
    -S $SourceCache\sourcekit-lsp `
    -Target ($null, "install")
}

#-------------------------------------------------------------------

# preflight
Invoke-VsDevShell $ArchX64
Build-ToolchainX64
Build-LlvmX64

# Windows x64 Build
Invoke-VsDevShell $ArchX64
Build-ZLib $ArchX64
Build-LibXml2 $ArchX64
Build-Curl $ArchX64
Build-Icu $ArchX64
Build-SwiftRuntime $ArchX64
Build-SwiftCorelibsLibdispatch $ArchX64
Build-SwiftCorelibsFoundation $ArchX64
Build-SwiftCorelibsXCTest $ArchX64

if (-not $OnlyX64)
{
  # Windows x86 Build
  Invoke-VsDevShell $ArchX86
  Build-ZLib $ArchX86
  Build-LibXml2 $ArchX86
  Build-Curl $ArchX86
  Build-Icu $ArchX86
  Build-SwiftRuntime $ArchX86
  Build-SwiftCorelibsLibdispatch $ArchX86
  Build-SwiftCorelibsFoundation $ArchX86
  Build-SwiftCorelibsXCTest $ArchX86

  # Windows ARM64 Runtime
  Invoke-VsDevShell $ArchArm64
  Build-ZLib $ArchArm64
  Build-LibXml2 $ArchArm64
  Build-Curl $ArchArm64
  Build-Icu $ArchArm64
  Build-SwiftRuntime $ArchArm64
  Build-SwiftCorelibsLibdispatch $ArchArm64
  Build-SwiftCorelibsFoundation $ArchArm64
  Build-SwiftCorelibsXCTest $ArchArm64
}

Invoke-VsDevShell $ArchX64
Build-SqliteX64
Build-SwiftSystemX64
Build-ToolsSupportCoreX64
Build-LLBuildX64
Build-YamsX64
Build-SwiftArgumentParserX64
Build-SwiftDriverX64
Build-SwiftCryptoX64
Build-SwiftCollectionsX64
Build-SwiftPackageManagerX64
Build-IndexStoreDBX64
Build-SwiftSyntaxX64
Build-SourceKitLspX64

# Switch to swift-driver
Copy-Item -Force $BinaryCache\7\bin\swift-driver.exe $ToolchainInstallRoot\usr\bin\swift.exe
Copy-Item -Force $BinaryCache\7\bin\swift-driver.exe $ToolchainInstallRoot\usr\bin\swiftc.exe

# SDKSettings.plist
.$python -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'DEFAULT_USE_RUNTIME': 'MD' } }), encoding='utf-8'))" > $SDKInstallRoot\SDKSettings.plist

# Info.plist
.$python -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'XCTEST_VERSION': 'development' } }), encoding='utf-8'))" > $PlatformInstallRoot\Info.plist
