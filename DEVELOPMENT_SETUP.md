# Development Environment Setup

This guide covers setting up Ansible development on **Windows** and **macOS**.

> [!IMPORTANT]
> **Ansible does not run natively on Windows.** Windows users must use WSL (Windows Subsystem for Linux).
> macOS users can run Ansible natively.

---

## Quick Start

| Platform | Approach |
|----------|----------|
| **Windows** | WSL2 with Ubuntu |
| **macOS** | Native Python virtual environment |

---

## Windows Setup (WSL)

### Prerequisites

- Windows 10 (version 2004+) or Windows 11
- Administrator access

### 1. Install WSL

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu
```

Restart your computer when prompted. Ubuntu will then ask you to create a username and password.

### 2. Install Ansible in WSL

Open Ubuntu (from Start menu or type `wsl` in PowerShell/Terminal):

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Python
sudo apt install -y python3 python3-pip python3-venv

# Create virtual environment
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

# Install Ansible tools
pip install ansible ansible-lint yamllint

# Add auto-activation to bashrc
echo 'source ~/ansible-venv/bin/activate' >> ~/.bashrc

# Verify
ansible --version
```

### 3. Install Ansible Galaxy Collections

```bash
cd /mnt/c/Users/YOUR_USERNAME/path/to/pi-and-mikrotek-ansible-setup
ansible-galaxy collection install -r requirements.yml
```

### 4. VS Code Integration

1. Install [VS Code](https://code.visualstudio.com/)
2. Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
3. Open the project - the integrated terminal will automatically use Ubuntu WSL

---

## macOS Setup

### Prerequisites

- macOS 10.15 (Catalina) or later
- Homebrew (recommended) or Python 3.9+

### Option A: Using Homebrew (Recommended)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python@3.11

# Create virtual environment
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

# Install Ansible tools
pip install ansible ansible-lint yamllint

# Add auto-activation to your shell config
echo 'source ~/ansible-venv/bin/activate' >> ~/.zshrc  # or ~/.bashrc

# Verify
ansible --version
```

### Option B: Using System Python

```bash
# Create virtual environment
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

# Install Ansible tools
pip install ansible ansible-lint yamllint

# Add to shell config
echo 'source ~/ansible-venv/bin/activate' >> ~/.zshrc

# Verify
ansible --version
```

### Install Ansible Galaxy Collections

```bash
cd ~/path/to/pi-and-mikrotek-ansible-setup
ansible-galaxy collection install -r requirements.yml
```

---

## Testing Your Playbooks

These commands work on both platforms once Ansible is installed:

### Syntax Check (Fast - No Connection Needed)

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

### Lint Check (Fast - No Connection Needed)

```bash
ansible-lint .
```

### Dry Run with Test Inventory (No Pi Needed)

```bash
ansible-playbook playbooks/site.yml -i inventory/test.yml --check --diff
```

> [!NOTE]
> Some tasks will show "changed" or fail in check mode because they expect a real Raspberry Pi. This is expected.

### Dry Run Against Real Pi (SSH Required)

```bash
ansible-playbook playbooks/site.yml -i inventory/remote.yml --check --diff
```

---

## VS Code Tasks

Press `Ctrl+Shift+P` (Windows) or `Cmd+Shift+P` (Mac) → "Run Task":

| Task | Description |
|------|-------------|
| **Ansible: Syntax Check** | Validate playbook syntax |
| **Ansible: Lint All** | Run ansible-lint on project |
| **Ansible: Dry Run (Test Inventory - WSL)** | Local test with check mode |
| **Ansible: Dry Run - Remote Pi** | Test against real Pi (needs SSH) |
| **Ansible: Install Galaxy Collections** | Install required collections |

---

## SSH Setup for Remote Pi

To run playbooks against your actual Pi, set up SSH keys:

### Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### Copy Key to Pi

```bash
ssh-copy-id pi@192.168.88.253
```

### Test Connection

```bash
ssh pi@192.168.88.253
```

---

## Troubleshooting

### "Command not found: ansible"

The virtual environment isn't activated:
```bash
source ~/ansible-venv/bin/activate
```

### Windows: VS Code Terminal Shows PowerShell

1. Open terminal settings (`Ctrl+,` → search "terminal default")
2. Set default profile to "Ubuntu (WSL)"

Or click the dropdown arrow in the terminal panel and select "Ubuntu (WSL)".

### macOS: Permission Denied Errors

If pip install fails with permission errors, ensure you're using a virtual environment:
```bash
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate
pip install ansible ansible-lint yamllint
```

### SSH Connection to Pi Fails

1. Check Pi is reachable: `ping 192.168.88.253`
2. Verify SSH is enabled on Pi
3. Check SSH key is copied: `ssh-copy-id pi@192.168.88.253`

### Windows: WSL Path to Project

Your Windows files are accessible in WSL at `/mnt/c/...`:
```bash
cd /mnt/c/Users/addis/OneDrive/Documents/PersonalProjects/pi-and-mikrotek-ansible-setup
```

---

## Quick Reference

| Action | Windows (WSL) | macOS |
|--------|--------------|-------|
| Open terminal | `Ctrl+`` | `Cmd+`` |
| Activate venv | `source ~/ansible-venv/bin/activate` | `source ~/ansible-venv/bin/activate` |
| Project path | `/mnt/c/Users/.../project` | `~/path/to/project` |
| Run task | `Ctrl+Shift+P` → Run Task | `Cmd+Shift+P` → Run Task |
