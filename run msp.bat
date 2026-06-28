@echo off
:: Use %~dp0 to make the path dynamic and portable for any Windows device
set LOG_DIR=%~dp0
if "%LOG_DIR:~-1%"=="\" set LOG_DIR=%LOG_DIR:~0,-1%
set LOG_FILE=%LOG_DIR%\mpi_setup_log_final.txt
set DOWNLOAD_URL=https://learn.microsoft.com/en-us/message-passing-interface/microsoft-mpi

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo Starting Microsoft MPI Setup Process (Final) > "%LOG_FILE%"
date /t >> "%LOG_FILE%"
time /t >> "%LOG_FILE%"

echo Checking for Administrator privileges... >> "%LOG_FILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:CHECK_FILES
echo Checking for installation files... >> "%LOG_FILE%"
if not exist "%LOG_DIR%\msmpisetup.exe" goto MISSING_FILES
if not exist "%LOG_DIR%\msmpisdk.msi" goto MISSING_FILES
goto INSTALL_MPI

:MISSING_FILES
echo ERROR: Installation files missing. >> "%LOG_FILE%"
echo The files msmpisetup.exe and/or msmpisdk.msi are missing from %LOG_DIR%.
echo Opening the download page in your web browser.
echo Please download both files and place them in: %LOG_DIR%
start "" "%DOWNLOAD_URL%"
echo.
echo Press any key once you have placed both files in the folder to continue...
pause >nul
goto CHECK_FILES

:INSTALL_MPI
echo Installing MS-MPI Runtime... >> "%LOG_FILE%"
"%LOG_DIR%\msmpisetup.exe" -unattend >> "%LOG_FILE%" 2>&1
echo Runtime installation command executed. >> "%LOG_FILE%"

echo Installing MS-MPI SDK... >> "%LOG_FILE%"
msiexec /i "%LOG_DIR%\msmpisdk.msi" /quiet /qn /norestart >> "%LOG_FILE%" 2>&1
echo SDK installation command executed. >> "%LOG_FILE%"

echo Configuring Windows Firewall... >> "%LOG_FILE%"
netsh advfirewall firewall add rule name="Microsoft MPI TCP Ports" dir=in action=allow protocol=TCP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI UDP Ports" dir=in action=allow protocol=UDP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI Launch Service" dir=in action=allow program="%ProgramFiles%\Microsoft MPI\Bin\smpd.exe" enable=yes >> "%LOG_FILE%" 2>&1

echo Configuring MPI Service... >> "%LOG_FILE%"
sc config MsMpiLaunchSvc start= delayed-auto >> "%LOG_FILE%" 2>&1
sc start MsMpiLaunchSvc >> "%LOG_FILE%" 2>&1

echo Verifying MPI execution... >> "%LOG_FILE%"
echo.
echo ==========================================
echo Verifying MPI Installation...
echo Running test command: mpiexec -n 4 hostname
"%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n 4 hostname
if %errorlevel% equ 0 (
    echo.
    echo MPI successfully verified on this machine!
    echo MPI successfully verified on this machine. >> "%LOG_FILE%"
) else (
    echo.
    echo WARNING: mpiexec test failed. Check the log file.
    echo WARNING: mpiexec command failed or is not recognized. >> "%LOG_FILE%"
)
echo ==========================================
echo.

echo Setup process completed. >> "%LOG_FILE%"
echo Done. Please check the log file at "%LOG_FILE%".

:RUN_APP
echo.
set /p RUN_PROMPT="Setup is complete! Type 'R' if you want to run a custom MPI app now, or just press Enter to Exit: "
if /i "%RUN_PROMPT%" neq "R" goto END

:: Auto-detect executable in the same folder
set APP_PATH=
for %%f in ("%LOG_DIR%\*.exe") do (
    if /i not "%%~nxf"=="msmpisetup.exe" (
        set "APP_PATH=%%~f"
        goto FOUND_APP
    )
)

echo No other executable found in the current folder.
set /p APP_PATH="Enter the full path to the MPI executable: "
goto PROMPT_PROCS

:FOUND_APP
echo Auto-detected executable: "%APP_PATH%"
set /p CONFIRM_APP="Use this executable? (Y/N, or press Enter for Yes): "
if /i "%CONFIRM_APP%"=="N" (
    set /p APP_PATH="Enter the full path to the MPI executable: "
)

:PROMPT_PROCS
set /p NUM_PROCS="Enter the number of processes (e.g., 4): "
echo.
echo Running: "%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n %NUM_PROCS% "%APP_PATH%"
"%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n %NUM_PROCS% "%APP_PATH%"
echo.
pause

:END