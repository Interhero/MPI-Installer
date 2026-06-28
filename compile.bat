@echo off
setlocal
echo ==========================================
echo   Compiling MPI C++ Project
echo ==========================================
echo.

:: 1. Check if 'cl' is already available in the terminal
where cl >nul 2>&1
if %errorlevel% equ 0 goto COMPILE

:: 2. Try to find Visual Studio environment setup script automatically
set VCVARS=
for %%v in (Enterprise Professional Community BuildTools) do (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\%%v\VC\Auxiliary\Build\vcvars64.bat" (
        set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\%%v\VC\Auxiliary\Build\vcvars64.bat"
        goto SETUP_ENV
    )
)

:: 3. If Visual Studio is not installed at all, download and install it!
echo Microsoft C++ Compiler (cl.exe) is not installed on this computer.
echo Downloading Visual Studio 2022 Build Tools setup...
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'"

echo.
echo Installing C++ Build Tools in the background...
echo (Note: This downloads ~2GB of C++ tools and may take 5-15 minutes to finish)
echo Please wait patiently...
start /wait vs_buildtools.exe --quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended

echo.
echo Installation complete! 
set VCVARS="C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

:SETUP_ENV
echo Setting up C++ Developer Environment automatically...
call %VCVARS% >nul 2>&1

:COMPILE
echo.
echo Compiling mpi_analytics.cpp...
cl /EHsc /O2 mpi_analytics.cpp /I "%MSMPI_INC%" /link "%MSMPI_LIB64%\msmpi.lib" /out:mpi_analytics.exe
echo.
if exist mpi_analytics.exe (
    echo SUCCESS: mpi_analytics.exe has been compiled and created!
    echo You can now use Option 2 in run_msp.bat to run it over MPI.
) else (
    echo ERROR: Compilation failed.
)
pause
