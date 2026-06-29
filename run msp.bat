@echo off
setlocal
:: Ultimate Microsoft MPI & C++ Cluster Manager
:: Use %~dp0 to make the path dynamic and portable for any Windows device
set LOG_DIR=%~dp0
if "%LOG_DIR:~-1%"=="\" set LOG_DIR=%LOG_DIR:~0,-1%
set LOG_FILE=%LOG_DIR%\mpi_setup_log_final.txt
set DOWNLOAD_URL=https://learn.microsoft.com/en-us/message-passing-interface/microsoft-mpi

:: Check for Administrator privileges at startup so it covers all options
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:MAIN_MENU
cls
echo ======================================================
echo   Ultimate Microsoft MPI ^& C++ Cluster Manager
echo ======================================================
echo Please select an option:
echo.
echo 1. Install and Verify MPI on this Machine
echo 2. Install C++ Tools ^& Compile Project
echo 3. Auto-Configure Cluster Network ^& Accounts
echo 4. Run the MPI Application
echo 5. View Project Guides
echo 6. Exit
echo.
set /p MENU_CHOICE="Enter your choice (1-6): "

if "%MENU_CHOICE%"=="1" goto INSTALL_MPI
if "%MENU_CHOICE%"=="2" goto COMPILE_CPP
if "%MENU_CHOICE%"=="3" goto CLUSTER_SETUP
if "%MENU_CHOICE%"=="4" goto RUN_APP
if "%MENU_CHOICE%"=="5" goto PROJECT_GUIDES
if "%MENU_CHOICE%"=="6" goto END

goto MAIN_MENU


:: ==========================================
:: OPTION 1: INSTALL MPI
:: ==========================================
:INSTALL_MPI
cls
echo Checking for Administrator privileges... > "%LOG_FILE%"

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
"%LOG_DIR%\msmpisetup.exe" -unattend >> "%LOG_FILE%" 2>&1

echo Installing MS-MPI SDK...
msiexec /i "%LOG_DIR%\msmpisdk.msi" /quiet /qn /norestart >> "%LOG_FILE%" 2>&1

echo Configuring Windows Firewall...
netsh advfirewall firewall add rule name="Microsoft MPI TCP Ports" dir=in action=allow protocol=TCP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI UDP Ports" dir=in action=allow protocol=UDP localport=49152-65535 >> "%LOG_FILE%" 2>&1
netsh advfirewall firewall add rule name="Microsoft MPI Launch Service" dir=in action=allow program="%ProgramFiles%\Microsoft MPI\Bin\smpd.exe" enable=yes >> "%LOG_FILE%" 2>&1

echo Configuring MPI Service...
sc config MsMpiLaunchSvc start= delayed-auto >> "%LOG_FILE%" 2>&1
sc start MsMpiLaunchSvc >> "%LOG_FILE%" 2>&1

echo.
echo ==========================================
echo Verifying MPI Installation...
"%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n 4 hostname
if %errorlevel% equ 0 (
    echo.
    echo MPI successfully verified on this machine!
) else (
    echo.
    echo WARNING: mpiexec test failed. Check the log file.
)
echo ==========================================
echo.
pause
goto MAIN_MENU


:: ==========================================
:: OPTION 2: INSTALL C++ TOOLS & COMPILE
:: ==========================================
:COMPILE_CPP
cls
echo ==========================================
echo   Compiling MPI C++ Project
echo ==========================================
echo.

:: Generate starter C++ code if it doesn't exist
if not exist "%LOG_DIR%\mpi_analytics.cpp" (
    echo Generating starter C++ code ^(mpi_analytics.cpp^)...
    (
        echo #include ^<mpi.h^>
        echo #include ^<iostream^>
        echo int main^(int argc, char** argv^) {
        echo     MPI_Init^(&argc, &argv^);
        echo     int world_size, world_rank;
        echo     MPI_Comm_size^(MPI_COMM_WORLD, &world_size^);
        echo     MPI_Comm_rank^(MPI_COMM_WORLD, &world_rank^);
        echo     char processor_name[MPI_MAX_PROCESSOR_NAME];
        echo     int name_len;
        echo     MPI_Get_processor_name^(processor_name, &name_len^);
        echo     std::cout ^<^< "Hello from processor " ^<^< processor_name ^<^< ", rank " ^<^< world_rank ^<^< " out of " ^<^< world_size ^<^< " processors" ^<^< std::endl;
        echo     MPI_Finalize^();
        echo     return 0;
        echo }
    ) > "%LOG_DIR%\mpi_analytics.cpp"
)

:: Check if 'cl' is already available
where cl >nul 2>&1
if %errorlevel% equ 0 goto DO_COMPILE

:: Find Visual Studio environment
set VCVARS=
for %%d in ("C:\Program Files" "C:\Program Files (x86)") do (
    for %%v in (Enterprise Professional Community BuildTools) do (
        if exist "%%~d\Microsoft Visual Studio\2022\%%v\VC\Auxiliary\Build\vcvars64.bat" (
            set VCVARS="%%~d\Microsoft Visual Studio\2022\%%v\VC\Auxiliary\Build\vcvars64.bat"
            goto SETUP_ENV
        )
    )
)

:: Install Build Tools if missing
echo Microsoft C++ Compiler (cl.exe) is not installed.
echo Downloading Visual Studio 2022 Build Tools setup...
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'"

echo.
echo Installing C++ Build Tools (Downloads ~2GB, takes 5-15 mins)...
start /wait vs_buildtools.exe --quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended

set VCVARS=
for %%d in ("C:\Program Files" "C:\Program Files (x86)") do (
    if exist "%%~d\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" (
        set VCVARS="%%~d\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    )
)

:SETUP_ENV
echo Setting up C++ Developer Environment automatically...
call %VCVARS% >nul 2>&1

:DO_COMPILE
echo.
:: Fallback for MS-MPI SDK variables if not yet propagated to the current terminal session
if "%MSMPI_INC%"=="" set "MSMPI_INC=C:\Program Files (x86)\Microsoft SDKs\MPI\Include"
if "%MSMPI_LIB64%"=="" set "MSMPI_LIB64=C:\Program Files (x86)\Microsoft SDKs\MPI\Lib\x64"

echo Compiling mpi_analytics.cpp...
cd /d "%LOG_DIR%"
cl /EHsc /O2 mpi_analytics.cpp /I "%MSMPI_INC%" /link "%MSMPI_LIB64%\msmpi.lib" /out:mpi_analytics.exe
echo.
if exist mpi_analytics.exe (
    echo SUCCESS: mpi_analytics.exe has been compiled!
) else (
    echo ERROR: Compilation failed.
)
pause
goto MAIN_MENU


:: ==========================================
:: OPTION 3: CLUSTER SETUP
:: ==========================================
:CLUSTER_SETUP
cls
echo ======================================================
echo   Automated Cluster Setup Tool
echo ======================================================

set CLUSTER_USER=mpi_cluster
set CLUSTER_PASS=mpi123
set SHARED_DIR=C:\MPI_Project
set SHARE_NAME=MPI_Project

echo [1/4] Creating background local user account (%CLUSTER_USER%)...
net user %CLUSTER_USER% %CLUSTER_PASS% /add >nul 2>&1

echo [2/4] Granting Administrator privileges...
net localgroup Administrators %CLUSTER_USER% /add >nul 2>&1

echo [3/4] Creating dedicated project folder at %SHARED_DIR%...
if not exist "%SHARED_DIR%" mkdir "%SHARED_DIR%"

echo [4/4] Configuring Network Sharing and File Permissions...
net share %SHARE_NAME% /delete >nul 2>&1
net share %SHARE_NAME%="%SHARED_DIR%" /grant:%CLUSTER_USER%,FULL >nul 2>&1
icacls "%SHARED_DIR%" /grant %CLUSTER_USER%:(OI)(CI)F /T >nul 2>&1

echo.
echo CLUSTER SETUP COMPLETE!
echo Copy your compiled mpi_analytics.exe into %SHARED_DIR%.
echo.
echo Execute using:
echo mpiexec -user %CLUSTER_USER% -password %CLUSTER_PASS% -hosts 4 [IP1] 1 [IP2] 1 [IP3] 1 [IP4] 1 \\YourLaptopName\%SHARE_NAME%\mpi_analytics.exe
echo.
pause
goto MAIN_MENU


:: ==========================================
:: OPTION 4: RUN APP
:: ==========================================
:RUN_APP
cls
echo ==========================================
echo   Run MPI Application
echo ==========================================
echo.
echo Please select run mode:
echo [L] Run locally on this machine
echo [C] Run on a cluster of multiple computers
echo.
set /p RUN_MODE="Enter run mode (L/C): "

if /i "%RUN_MODE%"=="L" goto RUN_LOCAL
if /i "%RUN_MODE%"=="C" goto RUN_CLUSTER
goto RUN_APP

:RUN_LOCAL
cls
echo ==========================================
echo   Run Local MPI Application
echo ==========================================
set APP_PATH=
for %%f in ("%LOG_DIR%\*.exe") do (
    if /i not "%%~nxf"=="msmpisetup.exe" if /i not "%%~nxf"=="vs_buildtools.exe" (
        set "APP_PATH=%%~f"
        goto FOUND_LOCAL_APP
    )
)

echo No executable found in the current folder.
set /p APP_PATH="Enter the full path to the MPI executable (without quotes): "
goto PROMPT_LOCAL_PROCS

:FOUND_LOCAL_APP
echo Auto-detected executable: "%APP_PATH%"
set /p CONFIRM_APP="Use this executable? (Y/N, or press Enter for Yes): "
if /i "%CONFIRM_APP%"=="N" (
    set /p APP_PATH="Enter the full path to the MPI executable (without quotes): "
)

:PROMPT_LOCAL_PROCS
set /p NUM_PROCS="Enter the number of processes (e.g., 4): "
echo.
echo Running: "%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n %NUM_PROCS% "%APP_PATH%"
"%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -n %NUM_PROCS% "%APP_PATH%"
echo.
pause
goto MAIN_MENU


:RUN_CLUSTER
cls
echo ==========================================
echo   Run MPI Cluster Application
echo ==========================================
:: Auto-detect from C:\MPI_Project
set APP_PATH=
set SHARED_DIR=C:\MPI_Project
set SHARE_NAME=MPI_Project
for %%f in ("%SHARED_DIR%\*.exe") do (
    set "APP_PATH=\\%COMPUTERNAME%\%SHARE_NAME%\%%~nxf"
    goto FOUND_CLUSTER_APP
)

echo No executable found in the shared folder (%SHARED_DIR%).
echo Please compile your code first and copy the .exe to the shared folder.
set /p APP_PATH="Enter the UNC path to the shared executable (e.g., \\%COMPUTERNAME%\%SHARE_NAME%\mpi_analytics.exe): "
goto PROMPT_CLUSTER_INFO

:FOUND_CLUSTER_APP
echo Auto-detected shared executable: "%APP_PATH%"
set /p CONFIRM_APP="Use this executable? (Y/N, or press Enter for Yes): "
if /i "%CONFIRM_APP%"=="N" (
    set /p APP_PATH="Enter the UNC path to the shared executable: "
)

:PROMPT_CLUSTER_INFO
set /p NUM_HOSTS="Enter the number of computers in the cluster (2-4): "
if "%NUM_HOSTS%"=="2" (
    set /p IP1="Enter IP for Computer 1 (Master/Self): "
    set /p IP2="Enter IP for Computer 2 (Worker): "
    set HOSTS_ARG=2 %IP1% 1 %IP2% 1
)
if "%NUM_HOSTS%"=="3" (
    set /p IP1="Enter IP for Computer 1 (Master/Self): "
    set /p IP2="Enter IP for Computer 2 (Worker): "
    set /p IP3="Enter IP for Computer 3 (Worker): "
    set HOSTS_ARG=3 %IP1% 1 %IP2% 1 %IP3% 1
)
if "%NUM_HOSTS%"=="4" (
    set /p IP1="Enter IP for Computer 1 (Master/Self): "
    set /p IP2="Enter IP for Computer 2 (Worker): "
    set /p IP3="Enter IP for Computer 3 (Worker): "
    set /p IP4="Enter IP for Computer 4 (Worker): "
    set HOSTS_ARG=4 %IP1% 1 %IP2% 1 %IP3% 1 %IP4% 1
)

set /p NUM_PROCS="Enter the total number of processes to run across the cluster (e.g., 4): "
echo.
echo Running: "%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -user mpi_cluster -password mpi123 -hosts %HOSTS_ARG% -n %NUM_PROCS% "%APP_PATH%"
"%ProgramFiles%\Microsoft MPI\Bin\mpiexec.exe" -user mpi_cluster -password mpi123 -hosts %HOSTS_ARG% -n %NUM_PROCS% "%APP_PATH%"
echo.
pause
goto MAIN_MENU


:: ==========================================
:: OPTION 5: PROJECT GUIDES
:: ==========================================
:PROJECT_GUIDES
cls
echo ======================================================
echo   CSC580 Group Project Guide
echo ======================================================
echo 1. ENSURE LAN CONNECTION: All laptops must be on the same Wi-Fi/Ethernet.
echo 2. HOSTFILE: On the Master node, create 'hostfile.txt' with 4 IPs:
echo      192.168.x.x1
echo      192.168.x.x2...
echo.
echo 3. EXECUTE: The Node Master runs the distributed job:
echo    mpiexec -user mpi_cluster -password mpi123 -hosts 4 [IP1] 1 [IP2] 1 [IP3] 1 [IP4] 1 \\Laptop1\MPI_Project\mpi_analytics.exe 10000000
echo.
pause
goto MAIN_MENU

:: ==========================================
:: OPTION 6: EXIT
:: ==========================================
:END
exit /b