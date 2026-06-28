@echo off
:: Universal Microsoft MPI Installer & Guide
:: Use %~dp0 to make the path dynamic and portable for any Windows device
set LOG_DIR=%~dp0
if "%LOG_DIR:~-1%"=="\" set LOG_DIR=%LOG_DIR:~0,-1%
set LOG_FILE=%LOG_DIR%\mpi_setup_log_final.txt
set DOWNLOAD_URL=https://learn.microsoft.com/en-us/message-passing-interface/microsoft-mpi

:MAIN_MENU
cls
echo ======================================================
echo   Universal Microsoft MPI Installer ^& Project Guide
echo ======================================================
echo Please select an option:
echo.
echo 1. Install and Verify MPI on this Machine
echo 2. Run a Local MPI Application
echo 3. How to Connect Multiple Devices (Cluster Guide)
echo 4. CSC580 Group Project Guide (atifnewcastle/mpi-project)
echo 5. Exit
echo.
set /p MENU_CHOICE="Enter your choice (1-5): "

if "%MENU_CHOICE%"=="1" goto INSTALL_MPI
if "%MENU_CHOICE%"=="2" goto RUN_APP
if "%MENU_CHOICE%"=="3" goto CLUSTER_GUIDE
if "%MENU_CHOICE%"=="4" goto CSC580_GUIDE
if "%MENU_CHOICE%"=="5" goto END

goto MAIN_MENU

:INSTALL_MPI
cls
echo Checking for Administrator privileges... > "%LOG_FILE%"
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
goto DO_INSTALL

:MISSING_FILES
echo ERROR: Installation files missing. >> "%LOG_FILE%"
echo The files msmpisetup.exe and/or msmpisdk.msi are missing from "%LOG_DIR%".
echo Opening the download page in your web browser.
echo Please download both files and place them in the same folder as this script.
start "" "%DOWNLOAD_URL%"
echo.
echo Press any key once you have placed both files in the folder to continue...
pause >nul
goto CHECK_FILES

:DO_INSTALL
echo Installing MS-MPI Runtime...
echo Installing MS-MPI Runtime... >> "%LOG_FILE%"
"%LOG_DIR%\msmpisetup.exe" -unattend >> "%LOG_FILE%" 2>&1
echo Runtime installation command executed. >> "%LOG_FILE%"

echo Installing MS-MPI SDK...
echo Installing MS-MPI SDK... >> "%LOG_FILE%"
msiexec /i "%LOG_DIR%\msmpisdk.msi" /quiet /qn /norestart >> "%LOG_FILE%" 2>&1
echo SDK installation command executed. >> "%LOG_FILE%"

echo Configuring Windows Firewall...
echo Configuring Windows Firewall... >> "%LOG_FILE%"
netsh advfirewall firewall add rule name="Microsoft MPI TCP Ports" dir=in action=allow protocol=TCP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI UDP Ports" dir=in action=allow protocol=UDP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI Launch Service" dir=in action=allow program="%ProgramFiles%\Microsoft MPI\Bin\smpd.exe" enable=yes >> "%LOG_FILE%" 2>&1

echo Configuring MPI Service...
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
echo.
pause
goto MAIN_MENU


:RUN_APP
cls
echo ==========================================
echo   Run Local MPI Application
echo ==========================================
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
goto MAIN_MENU


:CLUSTER_GUIDE
cls
echo ======================================================
echo   How to Connect Multiple Devices (Cluster Guide)
echo ======================================================
echo To run your MPI application across multiple computers, ensure the following:
echo.
echo 1. INSTALL MPI: Run this installer script (Option 1) on EVERY computer.
echo 2. SAME ACCOUNT: You MUST use a Windows account with the EXACT same 
echo    Username and Password on all computers.
echo 3. SHARED FOLDER: The MPI .exe must be in a network shared folder that 
echo    all computers can access via the same path (e.g., \\MainPC\Shared\app.exe).
echo.
echo Example Command to run on the Main PC:
echo mpiexec -hosts 2 LaptopA LaptopB -n 4 \\LaptopA\Shared\app.exe
echo.
pause
goto MAIN_MENU


:CSC580_GUIDE
cls
echo ======================================================
echo   CSC580 Group Project Guide
echo ======================================================
echo 1. ENSURE LAN CONNECTION: All 4 group members' laptops must be on the 
echo    same Wi-Fi or Ethernet switch.
echo 2. INSTALL MPI: Ensure Option 1 (Install MPI) is run on all 4 laptops.
echo 3. HOSTFILE: On the Master node, create 'hostfile.txt' with the 4 IP addresses:
echo      192.168.x.x1
echo      192.168.x.x2
echo      192.168.x.x3
echo      192.168.x.x4
echo.
echo 4. COMPILE: Use this command on all nodes to build your C++ code:
echo    cl /EHsc /O2 mpi_analytics.cpp /I "%%MSMPI_INC%%" /link "%%MSMPI_LIB64%%\msmpi.lib" /out:mpi_analytics.exe
echo.
echo 5. EXECUTE: The Node Master runs the distributed job:
echo    mpiexec -n 4 -hosts 4 [IP1] 1 [IP2] 1 [IP3] 1 [IP4] 1 mpi_analytics.exe 10000000
echo.
pause
goto MAIN_MENU


:END
exit /b