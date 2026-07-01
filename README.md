# 📡 Universal Microsoft MPI & C++ Cluster Manager

This repository contains a single, unified setup script (**`run msp.bat`**) that fully automates compiling, installing, and configuring Microsoft MPI (Message Passing Interface) for parallel execution on Windows.

## 🚀 Setup Instructions (Just Run the `.bat` File)

To configure your machine, simply **double-click `run msp.bat`**. 
*(The script will automatically request Administrator privileges to apply firewall and network changes).*

Once open, use the main menu options in order:

### 1️⃣ Option 1: Install & Verify MPI
* Installs the MS-MPI Runtime and SDK in the background.
* Configures Windows Firewall rules.
* Installs and starts the `smpd` service (configured as Local System with desktop interaction).
* Runs a local test (`mpiexec -n 4 hostname`) to verify installation.

### 2️⃣ Option 2: Install C++ Tools & Compile
* Automatically creates a starter C++ code file (`mpi_analytics.cpp`) if it doesn't exist.
* Detects or installs the MSVC C++ compiler in the background.
* Compiles your C++ code into a ready-to-run `mpi_analytics.exe` file.

### 3️⃣ Option 3: Auto-Configure Cluster Network & Accounts
* Run this on **both** the Master and Worker computers.
* Automatically overrides Windows registry security blocks (LocalAccountTokenFilterPolicy, ForceGuest, RestrictRemoteClients).
* Sets Tailscale VPN connection profile to **Private** to prevent firewall drops.
* Configures the shared folder `C:\MPI_Project` for network application sharing.
* Creates a background local user account:
  * **Username:** `mpi_cluster`
  * **Password:** `mpi123`

---

## 👥 Testing Cluster Connection (Master & Worker)

Once Option 3 has been run on all machines, do the following to establish a connection:

1. **Switch Account to Local:** On both the Master and Worker laptops, sign out of Windows and log into the newly created **`mpi_cluster`** local account (Password: `mpi123`).
2. **Verify Connectivity (On Master):** Open a Command Prompt and run the test command using your Tailscale/LAN IP addresses:
   ```cmd
   mpiexec -pwd mpi123 -hosts 2 [Master_IP] 1 [Worker_IP] 1 hostname
   ```
   *If successful, it will print both computer hostnames on your screen!*

---

## 🏃 Running Your MPI Application
To execute your compiled C++ project across your cluster:
1. Copy your compiled `.exe` to the shared `C:\MPI_Project` folder on the Master node.
2. Select **Option 4** (Run the MPI Application) in `run msp.bat`.
3. Choose **`C`** (Cluster Mode) and follow the simple prompts to input the IP addresses.
