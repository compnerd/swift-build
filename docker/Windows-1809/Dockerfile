# escape=`

FROM mcr.microsoft.com/windows/servercore:1809-amd64

# Install windows buildtools.
RUN powershell mkdir .\TEMP\; `
    Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vs_buildtools.exe -OutFile .\TEMP\vs_buildtools.exe; `
    Start-Process .\TEMP\vs_buildtools.exe  -Wait -ArgumentList '--quiet --wait --norestart --nocache `
    --installPath C:\BuildTools `
    --add Microsoft.VisualStudio.Component.VC.CMake.Project `
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    --add Microsoft.VisualStudio.Component.Windows10SDK `
    --add Microsoft.VisualStudio.Component.Windows10SDK.18362'; `
    Remove-Item –path .\TEMP\vs_buildtools.exe

ADD swift-build.py /swift-build.py

# Install Swift toolchain.
# use the azure cli to get an installation of python as Component.CPython.x64 component of buildtools was removed in vs2019
RUN powershell Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; `
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; `
    Remove-Item –path .\AzureCLI.msi; `
    C:/Program` Files` `(x86`)/Microsoft` SDKs/Azure/CLI2/python.exe -m pip install tabulate azure-devops; `
    C:/Program` Files` `(x86`)/Microsoft` SDKs/Azure/CLI2/python.exe swift-build.py --download --build-id VS2019 --latest-artifacts --filter installer.exe --quiet; `
    Expand-Archive -Force installer.exe.zip .; `
    Start-Process installer.exe\installer.exe  -Wait -ArgumentList '/quiet'; `
    Remove-Item –path .\installer.exe –recurse

# Swift dev-env deploy
RUN powershell Invoke-WebRequest -Uri https://github.com/compnerd/swift-devenv/releases/download/v0.0.3/swift-devenv.exe -OutFile C:/Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/usr/bin/swift-devenv.exe;`
    Start-Process C:/Library/Developer/Toolchains/unknown-Asserts-development.xctoolchain/usr/bin/swift-devenv.exe -Wait -ArgumentList '--deploy'; `
    $env:INCLUDE = "C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/ucrt;C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/shared;C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/um;C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/winrt;C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/cppwinrt"; `
    $env:LIB = "C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/ucrt/x64;C:/Program Files (x86)/Windows Kits/10/Lib/10.0.18362.0/um/x64"


# Default to powershell
ENTRYPOINT ["C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
