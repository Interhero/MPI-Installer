@echo off
:: Automatic Cluster Configuration Script for Microsoft MPI
:: This script configures the internal settings needed for a multi-device MPI cluster.

echo ======================================================
echo   Microsoft MPI - Automated Cluster Setup Tool
echo ======================================================

echo Checking for Administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

set CLUSTER_USER=mpi_cluster
set CLUSTER_PASS=mpi123
set SHARED_DIR=C:\MPI_Project
set SHARE_NAME=MPI_Project

echo.
echo [1/4] Creating background local user account (%CLUSTER_USER%)...
net user %CLUSTER_USER% %CLUSTER_PASS% /add >nul 2>&1
if %errorlevel% equ 0 (
    echo  - Account created successfully.
) else (
    echo  - Account already exists or could not be created.
)

echo.
echo [2/4] Granting Administrator privileges to the account...
net localgroup Administrators %CLUSTER_USER% /add >nul 2>&1
echo  - Privileges granted.

echo.
echo [3/4] Creating dedicated project folder at %SHARED_DIR%...
if not exist "%SHARED_DIR%" mkdir "%SHARED_DIR%"
echo  - Folder ready.

echo.
echo [4/4] Configuring Network Sharing and File Permissions...
:: Remove old share if it exists to avoid errors
net share %SHARE_NAME% /delete >nul 2>&1
:: Create network share with full access for the cluster user
net share %SHARE_NAME%="%SHARED_DIR%" /grant:%CLUSTER_USER%,FULL >nul 2>&1
:: Enforce deep NTFS permissions for the cluster user
icacls "%SHARED_DIR%" /grant %CLUSTER_USER%:(OI)(CI)F /T >nul 2>&1
echo  - Sharing and permissions applied successfully.

echo.
echo ======================================================
echo   CLUSTER SETUP COMPLETE!
echo ======================================================
echo What happens now?
echo 1. Your dedicated network folder is located at: %SHARED_DIR%
echo 2. Place your compiled MPI application (.exe) inside that folder.
echo 3. The other laptops can now access this folder over the network.
echo.
echo IMPORTANT EXECUTION INSTRUCTIONS:
echo When you are ready to run the project, open a Command Prompt and 
echo run the mpiexec command explicitly using the cluster credentials:
echo.
echo mpiexec -user %CLUSTER_USER% -password %CLUSTER_PASS% -hosts 4 [IP1] 1 [IP2] 1 [IP3] 1 [IP4] 1 \\YourLaptopName\%SHARE_NAME%\mpi_analytics.exe
echo ======================================================
echo.
pause
exit /b
