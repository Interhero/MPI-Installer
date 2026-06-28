# Universal Microsoft MPI Installer

A portable and fully automated batch script to easily install, configure, and verify Microsoft MPI (Message Passing Interface) on any Windows machine.

## Features
- **True Portability**: Uses dynamic paths (`%~dp0`) so it can be run directly from a USB drive, network share, or local folder without needing a specific directory structure.
- **Automated Setup**: Installs both the MS-MPI Runtime and SDK silently with no user interaction required.
- **Firewall & Services Configuration**: Automatically opens the necessary TCP and UDP ports (`49152-65535`) in the Windows Firewall and configures the `MsMpiLaunchSvc` background service.
- **Auto-Verification**: Explicitly tests the installation by spinning up 4 parallel MPI processes on your machine and displaying the output.
- **App Auto-Detection**: Simply place your compiled MPI `.exe` application in the same folder as the installer. Once setup is complete, it will automatically detect your program and allow you to instantly run it across multiple processes.

## Usage
1. Clone or download this repository.
2. Ensure that `msmpisetup.exe` and `msmpisdk.msi` are in the same folder as `run msp.bat`. (If missing, the script will direct you to download them).
3. **Double-click `run msp.bat`**. 
   *(The script automatically requests Administrator privileges if you aren't running it as an admin yet).*
4. Let the setup run. 
5. When complete, press Enter to exit, or type 'R' to run a custom MPI application.

## Requirements
- Windows OS (64-bit recommended)
- Administrator Privileges (Auto-requested by the script)
