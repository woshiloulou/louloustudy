@echo off
set NEXUS_IP=192.168.1.100
set NEXUS_PORT=8081
set SCRIPT_DIR=%~dp0

echo Setting up Nexus Configuration...

REM 1. Configure npm
echo Configuring npm registry to http://%NEXUS_IP%:%NEXUS_PORT%/repository/npm-group/
call npm config set registry http://%NEXUS_IP%:%NEXUS_PORT%/repository/npm-group/
echo npm registry set.

REM 2. Configure Maven (Copy settings.xml)
echo Configuring Maven...
if not exist "%USERPROFILE%\.m2" mkdir "%USERPROFILE%\.m2"

if exist "%SCRIPT_DIR%settings.xml" (
    copy /Y "%SCRIPT_DIR%settings.xml" "%USERPROFILE%\.m2\settings.xml"
    echo Maven settings.xml copied to %USERPROFILE%\.m2\
) else (
    echo WARNING: settings.xml not found in %SCRIPT_DIR%
    echo Please ensure settings.xml is in the same directory as this script.
)

echo Done!
pause
