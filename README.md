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






./setup-2fa.sh          # Interactive setup
./setup-2fa.sh status   # Check current 2FA status
./setup-2fa.sh revert   # Remove 2FA and restore backups
./setup-2fa.sh test     # Test configuration
./setup-2fa.sh help     # Show help










⚠️ Critical Warnings
Select authentication method:
1) SSH Key + Google Authenticator (BOTH required - RECOMMENDED)
2) Password + Google Authenticator (BOTH required)
3) SSH Key OR Google Authenticator (either one works)
Enter choice (1/2/3): 1
 why i choose both but when i log in and out it only ask for google ?


he issue is in your script! When you choose Option 1 (SSH Key + Google Authenticator), it should ask for BOTH, but it's only asking for Google Authenticator because:

The Problem:
SSH Key authentication happens automatically - SSH uses your private key without asking

Google Authenticator is asked interactively - You see the prompt

So it IS working correctly - you just don't see the SSH key part because it happens automatically!

What's Actually Happening:
When you SSH with a key:

SSH automatically authenticates with your private key (silent)

Then SSH asks for Google Authenticator code (visible)

Both are required, but only one is visible to you

To Test That BOTH Are Required:
Test 1: Try without SSH key

# Try connecting WITHOUT your SSH key
ssh ubuntu@13.62.229.152



It should FAIL because you need the SSH key.

Test 2: Try with wrong Google Auth code


# Try connecting WITH key but wrong Google Auth code
ssh -i /home/xela/.ssh/Task2.pem ubuntu@13.62.229.152
# Enter WRONG code (like 111111)
It should FAIL because the Google Auth code is wrong



On the server, check:
sudo tail -f /var/log/auth.log
The Script is Working Correctly!
Your script IS configured for "SSH Key + Google Authenticator (BOTH required)". Here's what it sets:



AuthenticationMethods publickey,keyboard-interactive
PasswordAuthentication no
PubkeyAuthentication yes



Summary:
Your script IS WORKING CORRECTLY! When using SSH keys:

SSH key authentication is automatic (no prompt)

Google Authenticator shows a prompt

Both are required for authentication

The configuration is correct: AuthenticationMethods publickey,keyboard-interactive means BOTH are required, even though only one shows a prompt.














