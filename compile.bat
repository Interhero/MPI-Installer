@echo off
echo ==========================================
echo   Compiling MPI C++ Project
echo ==========================================
echo.
echo Make sure you are running this from a "Developer Command Prompt for VS"
echo so that the 'cl' compiler is recognized!
echo.
cl /EHsc /O2 mpi_analytics.cpp /I "%MSMPI_INC%" /link "%MSMPI_LIB64%\msmpi.lib" /out:mpi_analytics.exe
echo.
if exist mpi_analytics.exe (
    echo SUCCESS: mpi_analytics.exe has been created!
    echo You can now use Option 2 in run_msp.bat to run it.
) else (
    echo ERROR: Compilation failed.
)
pause
