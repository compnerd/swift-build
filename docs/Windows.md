### Getting Started (Windows)

#### The Windows SDK and the Native Tools Command Prompt

You will need an installation of the Windows SDK to develop with the Swift toolchain described here. An easy way to get the Windows SDK is to install Visual Studio, currently Visual Studio 2017 is needed. The following instructions suppose that you have Visual Studio 2017 installed. This will also make the  `x64 Native Tools Command Prompt for VS 2017` available, it should be accessible from the `Visual Studio 2017` folder in the Start menu.

The following commands are to be executed from within this Native Tools Command Prompt. Be sure to always start the `x64` version of the Native Tools Command Prompt.

#### Files for the Windows SDK

You will need to copy a few files into the Windows SDK to make it usable for Swift development. As you might need  administrator rights to copy files into the Visual Studio installation directory, for the following four commands (and for those commands only) open the Native Tools Command Prompt with administrator rights. Otherwise, you might get a "Permission denied" error for some of those commands. Be sure that all commands have been successfully executed before continuing.

To open the Native Tools Command Prompt with administrator rights, navigate to the according entry in the start menu, right-click on that entry and choose "Open location" in the context menu. Then right-click the according file (that is actually a link) and choose "Run as administrator".

Then execute the following four commands from within the Native Tools Command Prompt:

```cmd
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/ucrt.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\ucrt\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.modulemap" -o "%VCToolsInstallDir%\include\module.modulemap"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/visualc.apinotes" -o "%VCToolsInstallDir%\include\visualc.apinotes"
curl -L "https://raw.githubusercontent.com/apple/swift/master/stdlib/public/Platform/winsdk.modulemap" -o "%UniversalCRTSdkDir%\Include\%UCRTVersion%\um\module.modulemap"
```

Close this instance of the Native Tools Command Prompt after those commands have been successfully executed.

#### Swift Toolchain & Platform SDK concepts

The installation instructions that follow will result in a directory tree that has a well thought-out structure. To understand this directory structure better you may consult  <https://github.com/compnerd/windows-swift/blob/master/docs/details.md>. But first, you might want to continue with the installation.

#### Downloading the nightlies

1. Go to  <https://dev.azure.com/compnerd/windows-swift>.
2. Choose `Pipelines` > `Pipelines` from the left of the dashboard.
3. Choose 'Runs'.
4. Use the filter symbol to search for "VS2017".
5. In the results list, scroll down until you see the first successful build (with a green OK symbol) and click on it.
6. Under "Artifacts", click on the "... published" link.
7. Download windows-toolchain-amd64.msi, windows-sdk.msi, and windows-runtime-amd64.msi by clicking on the appropriate down-arrows on the right. Be sure to really download these files from the same build (i.e. do not switch the build for the next download, and be careful when updating)! These files will be downloaded as zip files. Unless they are not automatically unzipped during the download process, unzip them to obtain *.msi files in the extracted directories.

#### Installing the nightlies

These *.msi files install the files to C:\Library. The complete Library directory can later be copied to a different location to be used there.

Double-click windows-toolchain-amd64.msi, windows-sdk.msi, and windows-runtime-amd64.msi to run the according installations, one by one. (The installation process started by windows-toolchain-amd64.msi might take a while. Each of those installations can be deinstalled separately via the Windows "Apps & Features" settings. Such an deinstallation leaves all files in C:\Library that are not part of the according installation.)

Those installations to not add any values to the PATH environment variable. The PATH environment variable has to adjusted separatly (see below).

The directories created by those installations are as follows:

- windows-toolchain-amd64.msi: `C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain`
- windows-sdk.msi: `C:\Library\Developer\Platforms\Windows.platform`
- windows-runtime-amd64.msi: `C:\Library\Swift\Current\bin`

#### Further requirements: CMake

On Windows, the most convenient setup for building Swift projects currently involves the use of CMake.  This requires CMake 3.15+ for Swift support.  You can download CMake from <https://cmake.org/>.

In the following, we assume you added CMake to the C:\Libary folder, so that the CMake executable is in `C:\Library\cmake\bin`.

#### Further requirements: ICU

You will need the ICU libraries from <http://site.icu-project.org/>. The nightlies are built against ICU 64.2 from the ICU project. You can download the binaries for that from http://download./files/icu4c/64.2/icu4c-64_2-Win64-MSVC2017.zip.
In these instructions we assume you rename the extracted icu folder `icu4c-64_2-Win64-MSVC2017` to `icu-64.2` and move it to `C:\Library` and that you rename `bin64` to `bin`.

_Note:_ Currently you also need `icu-63.1`.

#### Building Swift code

You should use a CMake project to build a Swift program. An example CMake project with support for mixed-language support is available at <https://github.com/compnerd/swift-cmake-demo>.

For building such a CMake project the following paths have to be added to the PATH environment variable (adjust those paths to your actual installation folders):

- `C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin`
- `C:\Library\cmake\bin`
- `C:\Library\icu-64.2\bin`

_Note:_ Currently, `C:\Library\icu-63.1\bin` has to be added, too.

You can choose to add those paths permanently to your PATH environment variable, or you formulate a Windows batch script that first adds those paths to the PATH environment variable and then calls the build commands which are listed below. Be sure to add those paths before other paths, so e.g. use

SET PATH=%SCRIPT_DIR%\cmake\bin;%PATH%

in the batch script. For the path to CMake, adding it permanently to your PATH environment variable does not really help (try `cmake -version` inside the Native Tools Command Prompt), you would have to set it manually in each instance the Native Tools Command Prompt first, so a batch script might be a good idea.

The following commands build the project mentioned above (including tests), to be executed inside the project directory after the PATH environment variable is set):

```cmd
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=YES
cd build
ninja
ninja test
```

Of course, those commands have to be executed inside the Native Tools Command Prompt.

In a Windows batch script, you might want to add  `|| goto :end` at the end of each of those commands plus an `:end` mark to ensure that this list of commands is interrupted as soon as an error occurs. A full batch script to build the project in `C:\tmp\swift-cmake-demo` then might look as follows (of course, that batch script has to be called from within the Native Tools Command Prompt):

```cmd
@ECHO OFF

SET HOME=%CD%

SET INSTALLATION_DIR=C:\Library

SET PROJECT_DIR=C:\tmp\swift-cmake-demo

SET PATH=%INSTALLATION_DIR%\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin;%PATH%
SET PATH=%INSTALLATION_DIR%\cmake\bin;%PATH%
SET PATH=%INSTALLATION_DIR%\icu-64.2\bin;%PATH%
SET PATH=%INSTALLATION_DIR%\icu-63.1\bin;%PATH%

CD "%PROJECT_DIR%"

cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=YES || goto :end
cd build || goto :end
ninja || goto :end
ninja test || goto :end

:end
CD "%HOME%"
```

#### Running the Swift program on the development machine

The files inside  `C:\Library\Swift\Current\bin` are needed to run the program on the  development machine, so `C:\Library\Swift\Current\bin` has to be added to the PATH environment variable in order to run the program.

Additionally, the DLL files from the ICU project (icudt*.dll, icuin*.dll, icuio*.dll, icutu*.dll, icuuc*.dll) have to be in your path.

So a batch script to run the project in `C:\tmp\swift-cmake-demo` may look as follows:

```cmd
@ECHO OFF

SET INSTALLATION_DIR=C:\Library

SET PROJECT_DIR=C:\tmp\swift-cmake-demo

SET PATH=%INSTALLATION_DIR%\Swift\Current\bin;%PATH%
SET PATH=%INSTALLATION_DIR%\icu-64.2\bin;%PATH%
SET PATH=%INSTALLATION_DIR%\icu-63.1\bin;%PATH%

chcp 65001
CALL "%PROJECT_DIR%\build\bin\HelloWorld.exe"

PAUSE
```

The command  ` chcp 65001` ensures that Unicode characters are printed correctly inside the Windows command shell. This script does _not_ have to be called from within the Native Tools Command Prompt, but can be called by just double-clicking it.

Of course, if you place the according DLL files from those directories beside your executable (just copy them, do not move them!), you can start your executable directly from a normal Windows command shell without adjusting the PATH environment variable.

Note that the files in `C:\Library\Swift\Current\bin` might be incomplete: depending on the use case, you might need some more files (see the error messages when trying to run the program). You should find missing files in one of the following directories:

- `C:\Library\Developer\Toolchains\unknown-Asserts-development.xctoolchain\usr\bin`
- `C:\Library\Developer\Platforms\Windows.platform\Developer\SDKs\Windows.sdk\usr\bin`

Copy the missing files to `C:\Library\Swift\Current\bin` (be sure not to move them!).

#### Running the Swift program on any machine

To run the Swift program on another machine, the files from the "Visual C++ Redistributable" in the according version have to be available on that machine (i.e. they have to be in your path). They can be made available by installing the according "Visual C++ Redistributable". As an alternative, as described on <https://msdn.microsoft.com/en-us/data/dd293565(v=vs.85)>, the according files can also be part of your application. They can be found (depending of your Visual Studio version) e.g. in

`C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Redist\MSVC\14.16.27012\x64\Microsoft.VC141.CRT`

Currently, you find the following files there:

- concrt140.dll
- msvcp140.dll
- msvcp140_1.dll
- msvcp140_2.dll
- vccorlib140.dll
- vcruntime140.dll
