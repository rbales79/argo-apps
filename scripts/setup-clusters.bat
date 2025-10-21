@echo off
REM Windows Batch Launcher for OpenShift Cluster Management
REM This launches the Git Bash setup script from Windows Command Prompt

echo ========================================
echo  OpenShift Cluster Management Setup
echo ========================================
echo.

REM Check if Git Bash is available
where bash >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Git Bash not found in PATH
    echo Please install Git for Windows first
    echo https://git-scm.com/download/win
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Check if the bash script exists
if not exist "%SCRIPT_DIR%windows-cluster-setup.sh" (
    echo ERROR: windows-cluster-setup.sh not found
    echo Please ensure both files are in the same directory
    pause
    exit /b 1
)

echo Starting Git Bash setup script...
echo.

REM Launch Git Bash with the setup script
bash "%SCRIPT_DIR%windows-cluster-setup.sh"

echo.
echo Setup complete! You can now use Git Bash for cluster management.
echo.
pause
