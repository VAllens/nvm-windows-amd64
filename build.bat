@echo off
SET INNOSETUP=%CD%\nvm.iss
SET ORIG=%CD%
REM SET GOPATH=%CD%\src
SET GOBIN=%CD%\bin
REM Support for older architectures
SET GOARCH=amd64

REM Cleanup existing build if it exists
if exist src\nvm.exe (
  del src\nvm.exe
)

REM Make the executable and add to the binary directory
echo ----------------------------
echo Building nvm.exe
echo ----------------------------
cd .\src
go build nvm.go

REM Group the file with the helper binaries
move nvm.exe "%GOBIN%"
cd ..\

REM Codesign the executable
echo ----------------------------
echo Sign the nvm executable...
echo ----------------------------
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a "%GOBIN%\nvm.exe"

for /f %%i in ('"%GOBIN%\nvm.exe" version') do set AppVersion=%%i
echo nvm.exe v%AppVersion% built.

REM Create the distribution folder
SET DIST=%CD%\dist\%AppVersion%

REM Remove old build files if they exist.
if exist "%DIST%" (
  echo ----------------------------
  echo Clearing old build in %DIST%
  echo ----------------------------
  rd /s /q "%DIST%"
)

REM Create the distribution directory
mkdir "%DIST%"

REM Create the "no install" zip version
for %%a in ("%GOBIN%") do (buildtools\zip -j -9 -r "%DIST%\nvm-noinstall-%GOARCH%.zip" "%CD%\LICENSE" %%a\* -x "%GOBIN%\nodejs.ico")

REM Generate update utility
echo ----------------------------
echo Generating update utility...
echo ----------------------------
cd .\updater
go build nvm-update.go
move nvm-update.exe "%DIST%"
cd ..\

REM Generate the installer (InnoSetup)
echo ----------------------------
echo Generating installer...
echo ----------------------------
buildtools\iscc "%INNOSETUP%" "/o%DIST%"

echo ----------------------------
echo Sign the installer
echo ----------------------------
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a "%DIST%\nvm-setup.exe"

echo ----------------------------
echo Sign the updater...
echo ----------------------------
buildtools\signtool.exe sign /debug /tr http://timestamp.sectigo.com /td sha256 /fd sha256 /a "%DIST%\nvm-update.exe"

echo ----------------------------
echo Bundle the installer...
echo ----------------------------
buildtools\zip -j -9 -r "%DIST%\nvm-setup-%GOARCH%.zip" "%DIST%\nvm-setup.exe"


echo ----------------------------
echo Bundle the updater...
echo ----------------------------
buildtools\zip -j -9 -r "%DIST%\nvm-update-%GOARCH%.zip" "%DIST%\nvm-update.exe"

del "%DIST%\nvm-update.exe"
del "%DIST%\nvm-setup.exe"

REM Generate checksums
echo ----------------------------
echo Generating checksums...
echo ----------------------------
for %%f in ("%DIST%"\*.*) do (certutil -hashfile "%%f" MD5 | find /i /v "md5" | find /i /v "certutil" >> "%%f.checksum.txt")
echo complete

echo ----------------------------
echo Cleaning up...
echo ----------------------------
del "%GOBIN%\nvm.exe"
echo complete
@REM del %GOBIN%\nvm-update.exe
@REM del %GOBIN%\nvm-setup.exe

echo NVM for Windows v%AppVersion% build completed. Available in %DIST%
@echo on
