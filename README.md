⚠️ Critical Warnings
BEFORE RUNNING THE SCRIPT:

Keep an active SSH session - Do NOT close your current connection

Have console access - Ensure you have out-of-band server access

Install Google Authenticator - Set up the app on your phone first

Save backup codes - Emergency codes are shown during setup

Test in staging first - Try on a non-production server initially












# 🔐 Google Authenticator 2FA Setup Tool

A comprehensive, interactive bash script for setting up Two-Factor Authentication (2FA) with Google Authenticator on Linux servers for SSH and sudo access.

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Security](https://img.shields.io/badge/Security-4285F4?style=for-the-badge&logo=google-authenticator&logoColor=white)

## ✨ Features

✅ **Interactive Setup Wizard** - Step-by-step guidance with color-coded output  
✅ **Multiple Authentication Methods** - Choose your preferred 2FA combination  
✅ **Automatic Backups** - All configuration files backed up before changes  
✅ **Safe Revert Option** - Easily undo changes if needed  
✅ **sudo 2FA Support** - Optional 2FA requirement for sudo commands  
✅ **QR Code Display** - Visual QR code for easy app setup  
✅ **Comprehensive Testing** - Built-in SSH connection testing  
✅ **Troubleshooting Tools** - Built-in diagnostic commands  

## 📋 Requirements

- Linux server (Ubuntu/Debian preferred)
- SSH access with sudo privileges
- Google Authenticator app installed on your phone
- **IMPORTANT**: Keep an active SSH session during setup

## 🚀 Quick Start

### Method 1: Direct Download & Run
```bash
# Download and execute
bash <(curl -s https://raw.githubusercontent.com/yourusername/2fa-setup-tool/main/setup-2fa.sh)









🛡️ Authentication Methods
The script supports three authentication methods:

1. SSH Key + 2FA (Recommended)
First factor: SSH private key

Second factor: Google Authenticator TOTP

Maximum security for production servers

2. Password + 2FA
First factor: User password

Second factor: Google Authenticator TOTP

Good balance of security and convenience

3. SSH Key OR 2FA
Either SSH key OR Google Authenticator

Convenient for personal servers

Less secure than requiring both











