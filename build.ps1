# Copyright 2020 Saleem Abdulrasool <compnerd@compnerd.org>
#

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
$ArchX64 = @{
  VSName = "amd64";
  ShortName = "x64";
  LLVMName = "x86_64";
  LLVMTarget = "x86_64-unknown-windows-msvc";
  CMakeName = "AMD64";
  BinaryDir = "bin64";
  BuildID = 100
}

$ArchX86 = @{
  VSName = "x86";
  ShortName = "x86";
  LLVMName = "i686";
  LLVMTarget = "i686-unknown-windows-msvc";
  CMakeName = "i686";
  BinaryDir = "bin32";
  BuildID = 200
}

$ArchARM64 = @{
  VSName = "arm64";
  ShortName = "arm64";
  LLVMName = "aarch64";
  LLVMTarget = "aarch64-unknown-windows-msvc";
  CMakeName = "aarch64";
  BinaryDir = "bin64a";
  BuildID = 300
}

$CurrentVSDevShellTargetArch = $null

$InitialEnvPaths = @{
  EXTERNAL_INCLUDE = $env:EXTERNAL_INCLUDE;
  INCLUDE = $env:INCLUDE;
  LIB = $env:LIB;
  LIBPATH = $env:LIBPATH;
  Path = $env:Path;
  __VSCMD_PREINIT_PATH = $env:__VSCMD_PREINIT_PATH
}

# Build functions
function Get-ProjectBuildDir($Arch, $ID)
{
  return "$BinaryCache\" + ($Arch.BuildID + $ID)
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
  # Restore path-style environment variables to avoid appending ever more entries
  foreach ($entry in $InitialEnvPaths.GetEnumerator())
  {
    [Environment]::SetEnvironmentVariable($entry.Name, $entry.Value, "Process")
  }

  & $VsDevShell -VsInstallationPath $VSInstallRoot -HostArch amd64 -Arch $Arch.VSName | Out-Null
  Check-LastExitCode
}

function Build-CMakeProject
{
  param
  (
    [CmdletBinding(PositionalBinding = $false)]
    $Arch,
    [CmdletBinding(PositionalBinding = $false)]
    [string] $B, # Build directory, passed to CMake
    [CmdletBinding(PositionalBinding = $false)]
    [string] $S, # Source directory, passed to CMake
    [CmdletBinding(PositionalBinding = $false)]
    [string] $G, # Generator, passed to CMake
    [CmdletBinding(PositionalBinding = $false)]
    [switch] $BuildDefaultTarget = $false,
    [CmdletBinding(PositionalBinding = $false)]
    [string[]] $BuildTargets = @(),
    [CmdletBinding(PositionalBinding = $false)]
    [switch] $Install = $false
  )
  
  Write-Host -ForegroundColor Cyan "Building '$S' to '$B' for arch '$($Arch.ShortName)'..."

  # Make sure we have the right VSDevShell target architecture for building
  if ($Arch -ne $CurrentVSDevShellTargetArch) {
    Invoke-VsDevShell $Arch
    $CurrentVSDevShellTargetArch = $Arch
  }

  # Generate the project
  cmake -B $B -S $S -G $G @args
  Check-LastExitCode

  # Build all requested targets
  if ($BuildDefaultTarget)
  {
    cmake --build $B
    Check-LastExitCode
  }

  foreach ($Target in $BuildTargets)
  {
    cmake --build $B --target $Target
    Check-LastExitCode
  }
  
  if ($Install)
  {
    cmake --build $B --target install
    Check-LastExitCode
  }
}

function Build-Toolchain($Arch)
{
  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\1 `
    -C $SourceCache\swift\cmake\caches\Windows-$($Arch.LLVMName).cmake `
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
    -BuildTargets "distribution","install-distribution"

  # Restructure Internal Modules
  Remove-Item -Recurse -Force  -ErrorAction Ignore `
    $ToolchainInstallRoot\usr\include\_InternalSwiftScan
  Move-Item -Force `
    $ToolchainInstallRoot\usr\lib\swift\_InternalSwiftScan `
    $ToolchainInstallRoot\usr\include
  Move-Item -Force `
    $ToolchainInstallRoot\usr\lib\swift\windows\_InternalSwiftScan.lib `
    $ToolchainInstallRoot\usr\lib
}

function Build-LLVM($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 0

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D LLVM_HOST_TRIPLE=$($Arch.LLVMTarget) `
    -G Ninja `
    -S $SourceCache\llvm-project\llvm
}

function Build-ZLib($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -Arch $Arch `
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
    -BuildDefaultTarget `
    -Install
}

function Build-XML2($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -Arch $Arch `
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
    -BuildDefaultTarget `
    -Install
}

function Build-CURL($Arch)
{
  $ArchName = $Arch.ShortName

  Build-CMakeProject `
    -Arch $Arch `
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
    -BuildDefaultTarget `
    -Install
}

function Build-ICU($Arch)
{
  $ArchName = $Arch.ShortName

  if (-not(Test-Path -Path "$SourceCache\icu\icu4c\CMakeLists.txt"))
  {
    Copy-Item $SourceCache\swift-installer-scripts\shared\ICU\CMakeLists.txt $SourceCache\icu\icu4c\
    Copy-Item $SourceCache\swift-installer-scripts\shared\ICU\icupkg.inc.cmake $SourceCache\icu\icu4c\
  }

  if ($Arch -eq $ArchARM64)
  {
    # Use previously built x64 tools
    $BuildToolsArgs = @(
      "-D", "BUILD_TOOLS=NO",
      "-D", "ICU_TOOLS_DIR=S:\b\icu-69.1.x64\Tools"
    )
  }
  else
  {
    $BuildToolsArgs = @(
      "-D", "BUILD_TOOLS=YES"
    )
  }

  # Specifying "-BuildTargets @()" works around a PowerShell bug,
  # where the first @-expanded argument would be passed to
  # -BuildTargets because it is an array.
  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\icu-69.1.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    @BuildToolsArgs `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_MT=mt `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\icu-69.1\usr `
    -D CMAKE_INSTALL_BINDIR=bin/$ArchName `
    -D CMAKE_INSTALL_LIBDIR=lib/$ArchName `
    -G Ninja `
    -S $SourceCache\icu\icu4c `
    -BuildDefaultTarget `
    -BuildTargets @() `
    -Install
}

function Build-SwiftRuntime($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 1

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinDir `
    -C "$SourceCache\swift\cmake\caches\Runtime-Windows-$($Arch.LLVMName).cmake" `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER_TARGET=$($Arch.LLVMTarget) `
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
    -BuildDefaultTarget `
    -Install

  # Restructure runtime
  mkdir  -ErrorAction Ignore `
    $InstallRoot\swift-development\usr\bin\$($Arch.ShortName)
  Move-Item -Force `
    $SDKInstallRoot\usr\bin\*.dll `
    $InstallRoot\swift-development\usr\bin\$($Arch.ShortName)\
}

function Build-Dispatch($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 2
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinDir `
    -D BUILD_TESTING=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$($Arch.CMakeName) `
    -D CMAKE_INSTALL_PREFIX=$SDKInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D ENABLE_SWIFT=YES `
    -G Ninja `
    -S $SourceCache\swift-corelibs-libdispatch `
    -BuildDefaultTarget `
    -Install

  # Restructure Runtime
  Move-Item -Force `
    $SDKInstallRoot\usr\bin\*.dll `
    $InstallRoot\swift-development\usr\bin\x64\

  # Restructure BlocksRuntime, dispatch headers
  foreach ($module in ("Block", "dispatch", "os"))
  {
    Remove-Item -Recurse -Force -ErrorAction Ignore `
      $SDKInstallRoot\usr\include\$module
    Move-Item -Force `
      $SDKInstallRoot\usr\lib\swift\$module `
      $SDKInstallRoot\usr\include\
  }

  # Restructure Import Libraries
  foreach ($module in ("BlocksRuntime", "dispatch", "swiftDispatch"))
  {
    Move-Item -Force `
      $SDKInstallRoot\usr\lib\swift\windows\$($module).lib `
      $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)
  }

  # Restructure Module
  mkdir -ErrorAction Ignore `
    $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule
  Move-Item -Force `
    $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)\Dispatch.swiftmodule `
    $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule\$($Arch.LLVMTarget).swiftmodule
  Move-Item -Force `
    $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)\Dispatch.swiftdoc `
    $SDKInstallRoot\usr\lib\swift\windows\Dispatch.swiftmodule\$($Arch.LLVMTarget).swiftdoc
}

function Build-Foundation($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 3
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"
  $DispatchBinDir = Get-ProjectBuildDir $Arch 2
  $ShortArch = $Arch.ShortName

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_ASM_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_ASM_FLAGS="--target=$($Arch.LLVMTarget)" `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_C_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$($Arch.CMakeName) `
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
    -BuildDefaultTarget `
    -Install

  # Restructure Runtime
  Move-Item -Force `
    $SDKInstallRoot\usr\bin\*.dll `
    $InstallRoot\swift-development\usr\bin\$ShortArch\
  Move-Item -Force `
    $SDKInstallRoot\usr\bin\*.exe `
    $InstallRoot\swift-development\usr\bin\$ShortArch\

  # Remove CoreFoundation Headers
  foreach ($module in ("CoreFoundation", "CFXMLInterface", "CFURLSessionInterface"))
  {
    Remove-Item -Recurse -Force -ErrorAction Ignore `
      $SDKInstallRoot\usr\lib\swift\$module
  }

  # Restructure Import Libraries, Modules
  foreach ($module in ("Foundation", "FoundationNetworking", "FoundationXML"))
  {
    Move-Item -Force `
      $SDKInstallRoot\usr\lib\swift\windows\$($module).lib `
      $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)

    mkdir $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule -ErrorAction Ignore
    Move-Item -Force `
      $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)\$($module).swiftmodule `
      $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule\$($Arch.LLVMTarget).swiftmodule
    Move-Item -Force `
      $SDKInstallRoot\usr\lib\swift\windows\$($Arch.LLVMName)\$($module).swiftdoc `
      $SDKInstallRoot\usr\lib\swift\windows\$($module).swiftmodule\$($Arch.LLVMTarget).swiftdoc
  }
}

function Build-XCTest($Arch)
{
  $BinDir = Get-ProjectBuildDir $Arch 4
  $SwiftLibDir = (Get-ProjectBuildDir $Arch 1) + "\lib\swift"
  $DispatchBinDir = Get-ProjectBuildDir $Arch 2
  $FoundationBinDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinDir `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_COMPILER_TARGET=$($Arch.LLVMTarget) `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftLibDir -L $SwiftLibDir\windows" `
    -D CMAKE_SYSTEM_NAME=Windows `
    -D CMAKE_SYSTEM_PROCESSOR=$($Arch.CMakeName) `
    -D CMAKE_INSTALL_PREFIX=$PlatformInstallRoot\Developer\Library\XCTest-development\usr `
    -D dispatch_DIR=$DispatchBinDir\cmake\modules `
    -D Foundation_DIR=$FoundationBinDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-corelibs-xctest `
    -BuildDefaultTarget `
    -Install

  # Restructure Runtime
  Remove-Item -Recurse -Force -ErrorAction Ignore `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\$($Arch.BinaryDir)
  Move-Item -Force `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\bin `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\$($Arch.BinaryDir)

  $LlvmArch = $Arch.LLVMName

  # Restructure Import Libraries
  mkdir -ErrorAction Ignore `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\
  Move-Item -Force `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.lib `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.lib

  # Restructure Module
  mkdir $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule -ErrorAction Ignore
  Move-Item -Force `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.swiftdoc `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule\$($Arch.LLVMTarget).swiftdoc
  Move-Item -Force `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\$LlvmArch\XCTest.swiftmodule `
    $PlatformInstallRoot\Developer\Library\XCTest-development\usr\lib\swift\windows\XCTest.swiftmodule\$($Arch.LLVMTarget).swiftmodule
}

function Build-SQLite($Arch)
{
  $ArchName = $Arch.ShortName
  $Dest = "$SourceCache\sqlite-3.36.0"

  # Download the sources
  mkdir "S:\var\cache" -ErrorAction Ignore
  if (-not (Test-Path -Path "S:\var\cache\sqlite-amalgamation-3360000.zip"))
  {
    curl.exe -sL https://sqlite.org/2021/sqlite-amalgamation-3360000.zip -o S:\var\cache\sqlite-amalgamation-3360000.zip
  }

  if (-not (Test-Path -Path $Dest))
  {
    mkdir $Dest -ErrorAction Ignore
    ."$env:ProgramFiles\Git\usr\bin\unzip.exe" -j -o S:\var\cache\sqlite-amalgamation-3360000.zip -d $Dest
    Copy-Item $SourceCache\swift-build\cmake\SQLite\CMakeLists.txt $Dest\
  }

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\sqlite-3.36.0.$ArchName `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_INSTALL_PREFIX=$InstallRoot\sqlite-3.36.0\usr `
    -D CMAKE_INSTALL_LIBDIR=lib/$ArchName `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\sqlite-3.36.0 `
    -BuildDefaultTarget `
    -Install
}

function Build-SwiftSystem($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\2 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\swift-system `
    -BuildDefaultTarget `
    -Install
}

function Build-ToolsSupportCore($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\3 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\swift-tools-support-core `
    -BuildDefaultTarget `
    -Install
}

function Build-LLBuild($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\4 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_CXX_COMPILER=cl `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D LLBUILD_SUPPORT_BINDINGS=Swift `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\llbuild `
    -BuildDefaultTarget `
    -Install
}

function Build-Yams($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3
  $XCTestBuildDir = Get-ProjectBuildDir $Arch 4

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\5 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -D XCTest_DIR=$XCTestBuildDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\Yams `
    -BuildDefaultTarget
}

function Build-ArgumentParser($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3
  $XCTestBuildDir = Get-ProjectBuildDir $Arch 4

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\6 `
    -D BUILD_SHARED_LIBS=YES `
    -D BUILD_TESTING=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -D XCTest_DIR=$XCTestBuildDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-argument-parser `
    -BuildDefaultTarget `
    -Install
}

function Build-Driver($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\7 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -D SwiftSystem_DIR=$BinaryCache\2\cmake\modules `
    -D TSC_DIR=$BinaryCache\3\cmake\modules `
    -D LLBuild_DIR=$BinaryCache\4\cmake\modules `
    -D Yams_DIR=$BinaryCache\5\cmake\modules `
    -D ArgumentParser_DIR=$BinaryCache\6\cmake\modules `
    -D SQLite3_INCLUDE_DIR=$InstallRoot\sqlite-3.36.0\usr\include `
    -D SQLite3_LIBRARY=$InstallRoot\sqlite-3.36.0\usr\lib\SQLite3.lib `
    -G Ninja `
    -S $SourceCache\swift-driver `
    -BuildDefaultTarget `
    -Install
}

function Build-Crypto($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\8 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\swift-crypto `
    -BuildDefaultTarget
}

function Build-Collections($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\9 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -G Ninja `
    -S $SourceCache\swift-collections `
    -BuildDefaultTarget `
    -Install
}

function Build-PackageManager($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\10 `
    -D BUILD_SHARED_LIBS=YES `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-DCRYPTO_v2 -resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
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
    -BuildDefaultTarget `
    -Install
}

function Build-IndexStoreDB($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\11 `
    -D BUILD_SHARED_LIBS=NO `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_CXX_FLAGS="-Xclang -fno-split-cold-code" `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_CXX_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
    -G Ninja `
    -S $SourceCache\indexstore-db `
    -BuildDefaultTarget
}

function Build-Syntax($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\12 `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -G Ninja `
    -S $SourceCache\swift-syntax `
    -BuildDefaultTarget `
    -Install
}

function Build-SourceKitLSP($Arch)
{
  $SwiftBuildDir = Get-ProjectBuildDir $Arch 1
  $DispatchBuildDir = Get-ProjectBuildDir $Arch 2
  $FoundationBuildDir = Get-ProjectBuildDir $Arch 3

  Build-CMakeProject `
    -Arch $Arch `
    -B $BinaryCache\13 `
    -D CMAKE_BUILD_TYPE=Release `
    -D CMAKE_C_COMPILER=S:/b/1/bin/clang-cl.exe `
    -D CMAKE_Swift_COMPILER=S:/b/1/bin/swiftc.exe `
    -D CMAKE_Swift_FLAGS="-resource-dir $SwiftBuildDir\lib\swift -L $SwiftBuildDir\lib\swift\windows" `
    -D CMAKE_INSTALL_PREFIX=$ToolchainInstallRoot\usr `
    -D CMAKE_MT=mt `
    -D dispatch_DIR=$DispatchBuildDir\cmake\modules `
    -D Foundation_DIR=$FoundationBuildDir\cmake\modules `
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
    -BuildDefaultTarget `
    -Install
}

#-------------------------------------------------------------------

# Compilers
Build-Toolchain $ArchX64
Build-LLVM $ArchX64

foreach ($Arch in $ArchX64,$ArchX86,$ArchARM64)
{
  Build-ZLib $Arch
  Build-XML2 $Arch
  Build-CURL $Arch
  Build-ICU $Arch
  Build-SwiftRuntime $Arch
  Build-Dispatch $Arch
  Build-Foundation $Arch
  Build-XCTest $Arch
}

Build-SQLite $ArchX64
Build-SwiftSystem $ArchX64
Build-ToolsSupportCore $ArchX64
Build-LLBuild $ArchX64
Build-Yams $ArchX64
Build-ArgumentParser $ArchX64
Build-Driver $ArchX64
Build-Crypto $ArchX64
Build-Collections $ArchX64
Build-PackageManager $ArchX64
Build-IndexStoreDB $ArchX64
Build-Syntax $ArchX64
Build-SourceKitLSP $ArchX64

# Switch to swift-driver
Copy-Item -Force $BinaryCache\7\bin\swift-driver.exe $ToolchainInstallRoot\usr\bin\swift.exe
Copy-Item -Force $BinaryCache\7\bin\swift-driver.exe $ToolchainInstallRoot\usr\bin\swiftc.exe

# SDKSettings.plist
.$python -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'DEFAULT_USE_RUNTIME': 'MD' } }), encoding='utf-8'))" > $SDKInstallRoot\SDKSettings.plist

# Info.plist
.$python -c "import plistlib; print(str(plistlib.dumps({ 'DefaultProperties': { 'XCTEST_VERSION': 'development' } }), encoding='utf-8'))" > $PlatformInstallRoot\Info.plist
