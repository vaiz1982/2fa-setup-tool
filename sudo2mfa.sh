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
    local timestamp=$(date +%Y%m%d_%H%M%S)
    if [[ -f "$file" ]]; then
        sudo cp "$file" "${file}.backup.${timestamp}"
        print_msg "Backup created: ${file}.backup.${timestamp}" "$GREEN"
    fi
}

# Function to test SSH connection
test_ssh() {
    local server_ip=$(hostname -I | awk '{print $1}')
    local username=$(whoami)
    
    print_msg "\n⚠️  IMPORTANT: Testing SSH connection..." "$YELLOW"
    print_msg "Open a NEW terminal window and try to connect to:" "$BLUE"
    print_msg "  ssh ${username}@${server_ip}" "$BLUE"
    print_msg "\nYou will be prompted for:" "$YELLOW"
    print_msg "1. SSH key passphrase (if using keys)" "$YELLOW"
    print_msg "2. Google Authenticator verification code" "$YELLOW"
    print_msg "\nKeep this terminal open until you confirm 2FA is working!" "$RED"
    
    read -p "Press Enter AFTER testing SSH connection (type 'skip' to skip test): " test_response
    
    if [[ "$test_response" == "skip" ]]; then
        print_msg "Skipping SSH test. Proceed with caution!" "$YELLOW"
    else
        read -p "Did SSH connection work with 2FA? (yes/no): " ssh_test
        if [[ "$ssh_test" != "yes" ]]; then
            print_msg "WARNING: SSH test may have failed!" "$RED"
            print_msg "Check /var/log/auth.log for details:" "$YELLOW"
            print_msg "  sudo tail -f /var/log/auth.log" "$YELLOW"
        else
            print_msg "✓ SSH connection with 2FA is working!" "$GREEN"
        fi
    fi
}

# Function to validate SSH configuration
validate_ssh_config() {
    print_msg "\n🔍 Validating SSH configuration syntax..." "$BLUE"
    if sudo sshd -t 2>/dev/null; then
        print_msg "✓ SSH configuration syntax is valid" "$GREEN"
        return 0
    else
        print_msg "✗ SSH configuration has syntax errors!" "$RED"
        print_msg "Checking for common issues..." "$YELLOW"
        
        # Check for specific issues
        if sudo grep -q "keyboard-interactive:pam" /etc/ssh/sshd_config; then
            print_msg "Found incorrect syntax: 'keyboard-interactive:pam'" "$RED"
            print_msg "Should be just 'keyboard-interactive'" "$GREEN"
        fi
        
        # Show the problematic line
        sudo sshd -t 2>&1 | grep -i "error\|failed"
        return 1
    fi
}

# Function to apply SSH configuration
apply_ssh_config() {
    local auth_choice="$1"
    
    print_msg "\n🔧 Applying SSH configuration..." "$BLUE"
    
    # Backup original sshd_config
    backup_file "/etc/ssh/sshd_config"
    
    # Create temporary configuration
    sudo cp /etc/ssh/sshd_config /tmp/sshd_config.tmp
    
    # Remove any existing AuthenticationMethods lines
    sudo sed -i '/^AuthenticationMethods/d' /tmp/sshd_config.tmp
    
    # Set common options
    sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /tmp/sshd_config.tmp
    sudo sed -i 's/^#*UsePAM.*/UsePAM yes/' /tmp/sshd_config.tmp
    
    case $auth_choice in
        1)
            # SSH Key + 2FA (BOTH required)
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /tmp/sshd_config.tmp
            echo "AuthenticationMethods publickey,keyboard-interactive" | sudo tee -a /tmp/sshd_config.tmp
            print_msg "Configured: SSH Key + Google Authenticator (BOTH required)" "$GREEN"
            ;;
        2)
            # Password + 2FA (BOTH required)
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /tmp/sshd_config.tmp
            echo "AuthenticationMethods password,keyboard-interactive" | sudo tee -a /tmp/sshd_config.tmp
            print_msg "Configured: Password + Google Authenticator (BOTH required)" "$GREEN"
            ;;
        3)
            # SSH Key OR 2FA (EITHER works)
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshdsudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /tmp/sshd_config.tmp
            echo "AuthenticationMethods publickey keyboard-interactive" | sudo tee -a /tmp/sshd_config.tmp
            print_msg "Configured: SSH Key OR Google Authenticator (either one works)" "$GREEN"
            ;;
        *)
            print_msg "Invalid choice, using SSH Key + 2FA (default)" "$YELLOW"
            sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /tmp/sshd_config.tmp
            sudo sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /tmp/sshd_config.tmp
            echo "AuthenticationMethods publickey,keyboard-interactive" | sudo tee -a /tmp/sshd_config.tmp
            ;;
    esac
    
    # Apply the new configuration
    sudo cp /tmp/sshd_config.tmp /etc/ssh/sshd_config
    sudo rm -f /tmp/sshd_config.tmp
    
    # Verify configuration
    print_msg "\n📋 SSH Configuration Applied:" "$BLUE"
    sudo grep -E "(AuthenticationMethods|ChallengeResponseAuthentication|UsePAM|KbdInteractiveAuthentication|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config | grep -v "^#"
}

# Function to configure PAM properly
configure_pam() {
    print_msg "\n🔧 Configuring PAM for SSH..." "$BLUE"
    backup_file "/etc/pam.d/sshd"
    
    # Create the correct PAM configuration
    sudo tee /etc/pam.d/sshd > /dev/null << 'EOF'
# PAM configuration for SSH with Google Authenticator
auth required pam_google_authenticator.so

# Comment out common-auth to use ONLY Google Authenticator
# If you want password + Google Auth, keep this line uncommented
# @include common-auth

# Disallow non-root logins when /etc/nologin exists.
account    required     pam_nologin.so

# Standard Un*x authorization.
@include common-account

# SELinux needs to be the first session rule.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so close

# Set the loginuid process attribute.
session    required     pam_loginuid.so

# Create a new session keyring.
session    optional     pam_keyinit.so force revoke

# Standard Un*x session setup and teardown.
@include common-session

# Print the message of the day upon successful login.
session    optional     pam_motd.so  motd=/run/motd.dynamic
session    optional     pam_motd.so noupdate

# Print the status of the user's mailbox upon successful login.
session    optional     pam_mail.so standard noenv

# Set up user limits from /etc/security/limits.conf.
session    required     pam_limits.so

# Read environment variables.
session    required     pam_env.so
session    required     pam_env.so user_readenv=1 envfile=/etc/default/locale

# SELinux needs to intervene at login time.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so open

# Standard Un*x password updating.
@include common-password
EOF
    
    print_msg "PAM configuration updated" "$GREEN"
    
    # Ask user if they want password + Google Auth
    print_msg "\n🔐 PAM Configuration Option:" "$BLUE"
    print_msg "1. Google Authenticator ONLY (recommended for SSH keys)" "$GREEN"
    print_msg "2. Password + Google Authenticator (two factors)" "$YELLOW"
    
    read -p "Choose PAM configuration (1/2): " pam_choice
    
    if [[ "$pam_choice" == "2" ]]; then
        # Enable password + Google Auth
        sudo sed -i 's/^# @include common-auth/@include common-auth/' /etc/pam.d/sshd
        print_msg "Configured: Password + Google Authenticator" "$GREEN"
    else
        # Ensure common-auth is commented (Google Auth only)
        sudo sed -i 's/^@include common-auth/# @include common-auth/' /etc/pam.d/sshd
        print_msg "Configured: Google Authenticator ONLY" "$GREEN"
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
    sudo apt install -y libpam-google-authenticator
    
    # Install qrencode if available
    if ! command -v qrencode &> /dev/null; then
        sudo apt install -y qrencode 2>/dev/null || print_msg "qrencode not available, skipping..." "$YELLOW"
    fi
    
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
    
    # Step 3: Configure PAM properly
    configure_pam
    
    # Step 4: Configure SSH server
    print_msg "\n🔐 Step 4: Configuring SSH server..." "$BLUE"
    
    # Ask for authentication method
    print_msg "\nSelect authentication method:" "$BLUE"
    print_msg "1) SSH Key + Google Authenticator (BOTH required - RECOMMENDED)" "$GREEN"
    print_msg "2) Password + Google Authenticator (BOTH required)" "$YELLOW"
    print_msg "3) SSH Key OR Google Authenticator (either one works)" "$YELLOW"
    
    read -p "Enter choice (1/2/3): " auth_choice
    
    # Apply SSH configuration
    apply_ssh_config "$auth_choice"
    
    # Validate configuration before restarting
    if validate_ssh_config; then
        # Step 5: Configure 2FA for sudo (optional)
        print_msg "\n🔧 Step 5: Configure 2FA for sudo? (optional)" "$BLUE"
        read -p "Require Google Authenticator for sudo commands? (yes/no): " sudo_2fa
        
        if [[ "$sudo_2fa" == "yes" ]]; then
            backup_file "/etc/pam.d/sudo"
            
            # Add to sudo PAM configuration
            if ! sudo grep -q "pam_google_authenticator.so" /etc/pam.d/sudo; then
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
    else
        print_msg "\n❌ Cannot proceed with setup due to configuration errors!" "$RED"
        print_msg "Please fix the SSH configuration manually." "$YELLOW"
        print_msg "You can restore from backup: /etc/ssh/sshd_config.backup.*" "$YELLOW"
        exit 1
    fi
}

# Function to revert changes
revert_2fa() {
    print_msg "\n🔄 REVERTING 2FA SETUP..." "$RED"
    
    print_msg "This will remove 2FA from SSH and sudo." "$YELLOW"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_msg "Revert cancelled." "$RED"
        exit 0
    fi
    
    # Remove from PAM SSH config
    sudo sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sshd
    
    # Remove from PAM sudo config
    sudo sed -i '/pam_google_authenticator.so/d' /etc/pam.d/sudo
    
    # Reset SSH config
    sudo sed -i '/^AuthenticationMethods/d' /etc/ssh/sshd_config
    sudo sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Restore from backup if exists
    if ls /etc/ssh/sshd_config.backup.* 1> /dev/null 2>&1; then
        latest_backup=$(ls -t /etc/ssh/sshd_config.backup.* | head -1)
        print_msg "Restoring SSH config from backup: $latest_backup" "$GREEN"
        sudo cp "$latest_backup" /etc/ssh/sshd_config
    fi
    
    if ls /etc/pam.d/sshd.backup.* 1> /dev/null 2>&1; then
        latest_backup=$(ls -t /etc/pam.d/sshd.backup.* | head -1)
        print_msg "Restoring PAM config from backup: $latest_backup" "$GREEN"
        sudo cp "$latest_backup" /etc/pam.d/sshd
    fi
    
    # Restart SSH
    sudo systemctl restart ssh
    
    print_msg "2FA has been disabled." "$GREEN"
    print_msg "Backup your ~/.google_authenticator file if needed." "$YELLOW"
}

# Function to show status
show_status() {
    print_msg "\n🔍 Current 2FA Status:" "$BLUE"
    print_msg "==========================================" "$BLUE"
    
    # Check Google Authenticator configuration
    if [[ -f ~/.google_authenticator ]]; then
        print_msg "✓ Google Authenticator configured for $(whoami)" "$GREEN"
    else
        print_msg "✗ Google Authenticator NOT configured" "$RED"
    fi
    
    # Check PAM configuration
    if sudo grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        print_msg "✓ PAM configured for SSH 2FA" "$GREEN"
        # Check if common-auth is enabled
        if sudo grep -q "^@include common-auth" /etc/pam.d/sshd; then
            print_msg "  → Password + Google Auth enabled" "$YELLOW"
        else
            print_msg "  → Google Auth ONLY enabled" "$YELLOW"
        fi
    else
        print_msg "✗ PAM NOT configured for SSH 2FA" "$RED"
    fi
    
    # Check sudo configuration
    if sudo grep -q "pam_google_authenticator.so" /etc/pam.d/sudo 2>/dev/null; then
        print_msg "✓ sudo requires 2FA" "$GREEN"
    else
        print_msg "✗ sudo does NOT require 2FA" "$YELLOW"
    fi
    
    print_msg "\n📋 SSH Configuration:" "$BLUE"
    print_msg "==========================================" "$BLUE"
    sudo grep -E "(AuthenticationMethods|ChallengeResponseAuthentication|UsePAM|KbdInteractiveAuthentication|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null | grep -v "^#"
    
    print_msg "\n🔧 Service Status:" "$BLUE"
    print_msg "==========================================" "$BLUE"
    sudo systemctl status ssh --no-pager | grep -E "(Active|Loaded)" || print_msg "Could not check SSH service" "$RED"
}

# Function to test configuration
test_config() {
    print_msg "\n🧪 Testing SSH configuration..." "$BLUE"
    
    # Test SSH syntax
    if sudo sshd -t; then
        print_msg "✓ SSH configuration syntax is valid" "$GREEN"
    else
        print_msg "✗ SSH configuration has syntax errors" "$RED"
        sudo sshd -t 2>&1 | grep -i "error\|failed"
    fi
    
    # Test PAM configuration
    if sudo grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
        print_msg "✓ PAM configuration found" "$GREEN"
    else
        print_msg "✗ PAM configuration missing" "$RED"
    fi
    
    # Check if user has Google Authenticator setup
    if [[ -f ~/.google_authenticator ]]; then
        print_msg "✓ User has Google Authenticator configured" "$GREEN"
    else
        print_msg "✗ User needs to run google-authenticator" "$RED"
    fi
}

# Function to show usage
show_usage() {
    print_msg "Usage: $0 [OPTION]" "$BLUE"
    print_msg "Options:" "$BLUE"
    print_msg "  setup     - Setup Google Authenticator (default)" "$GREEN"
    print_msg "  revert    - Revert 2FA changes" "$RED"
    print_msg "  status    - Show current 2FA status" "$YELLOW"
    print_msg "  test      - Test configuration without changes" "$BLUE"
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
    "status")
        show_status
        ;;
    "test")
        test_config
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    "")
        setup_2fa
        ;;
    *)
        print_msg "Unknown option: $1" "$RED"
        show_usage
        exit 1
        ;;
esac
