@echo off
setlocal enabledelayedexpansion

:: Check for Administrator privileges
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges to uninstall MPI and clean configuration...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

cls
echo ======================================================
echo   Microsoft MPI ^& Cluster Configuration Remover
echo ======================================================
echo.
echo This script will:
echo 1. Stop and remove the MS-MPI Launch Service (smpd).
echo 2. Silently uninstall MS-MPI Runtime and SDK.
echo 3. Delete the local 'mpi_cluster' user account.
echo 4. Remove MS-MPI firewall exceptions.
echo 5. Revert registry overrides.
echo 6. Optionally delete the shared C:\MPI_Project folder.
echo.
set /p CONFIRM="Are you sure you want to proceed? (Y/N): "
if /i "%CONFIRM%" neq "Y" (
    echo Uninstall cancelled.
    pause
    exit /b
)

echo.
echo ==========================================
echo 1. Stopping and Deleting smpd Service...
echo ==========================================
net stop MsMpiLaunchSvc >nul 2>&1
sc delete MsMpiLaunchSvc >nul 2>&1
net stop smpd >nul 2>&1
sc delete smpd >nul 2>&1
echo Done.

echo.
echo ==========================================
echo 2. Uninstalling MS-MPI Programs...
echo ==========================================
echo Searching registry for MS-MPI installations...
powershell -Command ^
    "$paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); ^
     Get-ItemProperty $paths | Where-Object { $_.DisplayName -like '*Microsoft MPI*' } | ForEach-Object { ^
         echo ('Uninstalling ' + $_.DisplayName + '...'); ^
         $uninstall = $_.UninstallString; ^
         if ($uninstall -like 'msiexec*') { ^
             $args = $uninstall.Split(' ', 2)[1] + ' /qn /norestart'; ^
             Start-Process msiexec.exe -ArgumentList $args -Wait; ^
         } ^
     }"
echo Done.

echo.
echo ==========================================
echo 3. Deleting 'mpi_cluster' User Account...
echo ==========================================
net user mpi_cluster /delete >nul 2>&1
if %errorlevel% equ 0 (
    echo Successfully deleted local user account 'mpi_cluster'.
) else (
    echo User account 'mpi_cluster' did not exist or was already deleted.
)

echo.
echo ==========================================
echo 4. Removing Firewall Rules...
echo ==========================================
netsh advfirewall firewall delete rule name="MS-MPI Launch Service" >nul 2>&1
netsh advfirewall firewall delete rule name="MS-MPI Ports" >nul 2>&1
echo Done.

echo.
echo ==========================================
echo 5. Reverting Registry Overrides...
echo ==========================================
:: Reset registry keys back to defaults or delete overrides we created
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v ForceGuest /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg" /v AllowedPaths /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictRemoteClients /f >nul 2>&1
echo Done.

echo.
echo ==========================================
echo 6. Cleaning Up Files...
echo ==========================================
set /p CLEAN_FOLDER="Do you want to delete the shared 'C:\MPI_Project' directory and datasets? (Y/N): "
if /i "%CLEAN_FOLDER%"=="Y" (
    echo Deleting C:\MPI_Project...
    rmdir /s /q "C:\MPI_Project" >nul 2>&1
    echo Done.
) else (
    echo Kept C:\MPI_Project directory.
)

echo.
echo ======================================================
echo   MS-MPI Cleanup ^& Uninstallation Complete!
echo ======================================================
echo.
pause
