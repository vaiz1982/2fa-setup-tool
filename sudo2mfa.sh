#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_msg() {
    echo -e "${2}${1}${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_msg "ERROR: Do not run this script as root!" "$RED"
        print_msg "Run as a regular user with sudo privileges." "$YELLOW"
        exit 1
    fi
}

# Function to backup files
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sudo cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_msg "Backup created: ${file}.backup" "$GREEN"
    fi
}

# Function to test SSH connection
test_ssh() {
    print_msg "\n⚠️  IMPORTANT: Testing SSH connection..." "$YELLOW"
    print_msg "Open a NEW terminal window and try to connect to:" "$BLUE"
    print_msg "  ssh $(whoami)@$(hostname -I | awk '{print $1}')" "$BLUE"
    print_msg "Keep this terminal open until you confirm 2FA is working!" "$YELLOW"
    
    read -p "Press Enter AFTER testing SSH connection (type 'skip' to skip test): " test_response
    
    if [[ "$test_response" == "skip" ]]; then
        print_msg "Skipping SSH test. Proceed with caution!" "$YELLOW"
    else
        print_msg "Did SSH connection work with 2FA? (yes/no): " "$BLUE"
        read ssh_test
        if [[ "$ssh_test" != "yes" ]]; then
            print_msg "WARNING: SSH test may have failed!" "$RED"
            print_msg "Check /var/log/auth.log for details" "$YELLOW"
        fi
    fi
}

# Main setup function
setup_2fa() {
    clear
    print_msg "==========================================" "$BLUE"
    print_msg "   GOOGLE AUTHENTICATOR SETUP SCRIPT     " "$BLUE"
    print_msg "==========================================" "$BLUE"
    
    # Check if not running as root
    check_root
    
    # Warning message
    print_msg "\n⚠️  ⚠️  ⚠️  CRITICAL WARNINGS ⚠️  ⚠️  ⚠️" "$RED"
    print_msg "1. Keep this SSH session open until setup is complete" "$YELLOW"
    print_msg "2. Have console/out-of-band access available" "$YELLOW"
    print_msg "3. Install Google Authenticator app on your phone first" "$YELLOW"
    print_msg "4. You will need to scan a QR code during setup" "$YELLOW"
    print_msg "5. Save backup codes in a secure location" "$YELLOW"
    
    read -p "Do you understand and accept these risks? (yes/no): " accept_risks
    
    if [[ "$accept_risks" != "yes" ]]; then
        print_msg "Setup cancelled." "$RED"
        exit 0
    fi
    
    # Step 1: Install Google Authenticator
    print_msg "\n📦 Step 1: Installing Google Authenticator..." "$BLUE"
    sudo apt update
    sudo apt install -y libpam-google-authenticator qrencode
    
    # Step 2: Configure 2FA for current user
    print_msg "\n👤 Step 2: Setting up Google Authenticator for user: $(whoami)" "$BLUE"
    print_msg "You will be prompted to:" "$YELLOW"
    print_msg "1. Scan QR code with Google Authenticator app" "$YELLOW"
    print_msg "2. Save emergency scratch codes" "$YELLOW"
    print_msg "3. Answer configuration questions" "$YELLOW"
    
    echo ""
    print_msg "Recommended answers:" "$GREEN"
    print_msg "  Do you want authentication tokens to be time-based? y" "$GREEN"
    print_msg "  Do you want me to update your ~/.google_authenticator file? y" "$GREEN"
    print_msg "  Do you want to disallow multiple uses? y" "$GREEN"
    print_msg "  Do you want to increase time window? n" "$GREEN"
    print_msg "  Do you want to enable rate-limiting? y" "$GREEN"
    
    read -p "Press Enter to start Google Authenticator setup..."
    
    # Run google-authenticator
    google-authenticator
    
    # Display QR code again if qrencode is available
    if command -v qrencode &> /dev/null && [[ -f ~/.google_authenticator ]]; then
        secret=$(head -n1 ~/.google_authenticator)
        print_msg "\n📱 Alternative QR Code Display:" "$BLUE"
        qrencode -t UTF8 "otpauth://totp/$(whoami)@$(hostname)?secret=$secret&issuer=SSH"
    fi
    
    # Step 3: Backup and configure PAM for SSH
    print_msg "\n🔧 Step 3: Configuring PAM for SSH..." "$BLUE"
    backup_file "/etc/pam.d/sshd"
    
    # Check if line already exists
    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        # Add at the beginning of the file
        sudo sed -i '1iauth required pam_google_authenticator.so' /etc/pam.d/sshd
        print_msg "Added Google Authenticator to PAM configuration" "$GREEN"
    else
        print_msg "Google Authenticator already in PAM configuration" "$YELLOW"
    fi
    
    # Step 4: Configure SSH server
    print_msg "\n🔐 Step 4: Configuring SSH server..." "$BLUE"
    backup_file "/etc/ssh/sshd_config"
    
    # Ask for authentication method
    print_msg "\nSelect authentication method:" "$BLUE"
    print_msg "1) SSH Key + Google Authenticator (RECOMMENDED)" "$GREEN"
    print_msg "2) Password + Google Authenticator" "$YELLOW"
    print_msg "3) SSH Key OR Google Authenticator (either one)" "$YELLOW"
    
    read -p "Enter choice (1/2/3): " auth_choice
    
    # Create temporary sshd_config
    sudo cp /etc/ssh/sshd_config /tmp/sshd_config.tmp
    
    # Set common options
    sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /tmp/sshd_config.tmp
    sudo sed -i 's/^#*UsePAM.*/UsePAM yes/' /tmp/sshd_config.tmp
    
    case $auth_choice in
        1)
            # SSH Key + 2FA
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive:pam/' /tmp/sshd_config.tmp
            print_msg "Configured: SSH Key + Google Authenticator (2 factors required)" "$GREEN"
            ;;
        2)
            # Password + 2FA
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*AuthenticationMethods.*/AuthenticationMethods password,keyboard-interactive:pam/' /tmp/sshd_config.tmp
            print_msg "Configured: Password + Google Authenticator (2 factors required)" "$GREEN"
            ;;
        3)
            # SSH Key OR 2FA
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*AuthenticationMethods.*/AuthenticationMethods publickey keyboard-interactive:pam/' /tmp/sshd_config.tmp
            print_msg "Configured: SSH Key OR Google Authenticator (either one works)" "$GREEN"
            ;;
        *)
            print_msg "Invalid choice, using SSH Key + 2FA (default)" "$YELLOW"
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive:pam/' /tmp/sshd_config.tmp
            ;;
    esac
    
    # Apply configuration
    sudo cp /tmp/sshd_config.tmp /etc/ssh/sshd_config
    sudo rm /tmp/sshd_config.tmp
    
    # Step 5: Configure 2FA for sudo (optional)
    print_msg "\n🔧 Step 5: Configure 2FA for sudo? (optional)" "$BLUE"
    read -p "Require Google Authenticator for sudo commands? (yes/no): " sudo_2fa
    
    if [[ "$sudo_2fa" == "yes" ]]; then
        backup_file "/etc/pam.d/sudo"
        
        # Add to sudo PAM configuration
        if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sudo; then
            echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sudo > /dev/null
            print_msg "Added Google Authenticator to sudo configuration" "$GREEN"
        else
            print_msg "Google Authenticator already in sudo configuration" "$YELLOW"
        fi
    fi
    
    # Step 6: Restart SSH service
    print_msg "\n🔄 Step 6: Restarting SSH service..." "$BLUE"
    sudo systemctl restart ssh
    
    # Step 7: Test connection
    test_ssh
    
    # Step 8: Display final configuration
    print_msg "\n✅ SETUP COMPLETE!" "$GREEN"
    print_msg "==========================================" "$BLUE"
    print_msg "Summary of changes:" "$BLUE"
    print_msg "1. Google Authenticator installed" "$GREEN"
    print_msg "2. 2FA configured for user: $(whoami)" "$GREEN"
    print_msg "3. SSH configured with 2FA" "$GREEN"
    
    if [[ "$sudo_2fa" == "yes" ]]; then
        print_msg "4. sudo requires 2FA" "$GREEN"
    fi
    
    print_msg "\n📋 Important Information:" "$BLUE"
    print_msg "Emergency scratch codes saved in: ~/.google_authenticator" "$YELLOW"
    print_msg "Backup codes location: ~/.google_authenticator" "$YELLOW"
    print_msg "SSH config backup: /etc/ssh/sshd_config.backup.*" "$YELLOW"
    print_msg "PAM config backup: /etc/pam.d/sshd.backup.*" "$YELLOW"
    
    print_msg "\n🔧 Troubleshooting commands:" "$BLUE"
    print_msg "Check SSH service: sudo systemctl status ssh" "$YELLOW"
    print_msg "View auth logs: sudo tail -f /var/log/auth.log" "$YELLOW"
    print_msg "Test SSH config: sudo sshd -T | grep -i auth" "$YELLOW"
    
    print_msg "\n⚠️  If you get locked out:" "$RED"
    print_msg "1. Use console/out-of-band access" "$YELLOW"
    print_msg "2. Restore from backup files" "$YELLOW"
    print_msg "3. Use emergency scratch codes" "$YELLOW"
    
    print_msg "\n🎉 Setup completed successfully!" "$GREEN"
}

# Function to revert changes
revert_2fa() {
    print_msg "\n🔄 REVERTING 2FA SETUP..." "$RED"
    
    # Remove from PAM SSH config
    sudo sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sshd
    
    # Remove from PAM sudo config
    sudo sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sudo
    
    # Reset SSH config to use keys only
    sudo sed -i 's/^AuthenticationMethods.*/#AuthenticationMethods publickey/' /etc/ssh/sshd_config
    sudo sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Restart SSH
    sudo systemctl restart ssh
    
    print_msg "2FA has been disabled. SSH now uses keys only." "$GREEN"
    print_msg "Backup your ~/.google_authenticator file if needed." "$YELLOW"
}

# Function to show usage
show_usage() {
    print_msg "Usage: $0 [OPTION]" "$BLUE"
    print_msg "Options:" "$BLUE"
    print_msg "  setup     - Setup Google Authenticator (default)" "$GREEN"
    print_msg "  revert    - Revert 2FA changes" "$RED"
    print_msg "  help      - Show this help message" "$BLUE"
}

# Main script execution
case "$1" in
    "setup")
        setup_2fa
        ;;
    "revert")
        revert_2fa
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        setup_2fa
        ;;
esac
