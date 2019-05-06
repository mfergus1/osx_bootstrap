#!/usr/bin/env bash
#
# Bootstrap script for setting up a new OSX machine
#
# This should be idempotent so it can be run multiple times.
#
# Some apps don't have a cask and so still need to be installed by hand if desired. Write
# them here:
# tensorflow, cuda, cudnn, spark
# Note that python packages are not currently being added in a virtualenv.
# Additional python packages should be installed within virtualenv that user prefers

#!/bin/bash

echo " Ask for the administrator password for the duration of this script"
sudo -kv


##################################
#### PACKAGE AND APP INSTALLS ####
##################################
echo " Starting bootstrapping"

# Check for Homebrew, install if we don't have it
if test ! $(which brew); then
    echo " Installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "Checking for Xcode Command Line Tools"
gcc --version > /dev/null

# Update homebrew recipes
brew update

# Add Homebrew path in PATH
echo "# Homebrew" >> ~/.bash_profile
echo "export PATH=/usr/local/bin:$PATH" >> ~/.bash_profile
source ~/.bash_profile

# Install Bash 4
brew install bash

# Install Cask
brew install cask

# Install dialog
brew install dialog

if ! brew info cask &>/dev/null; then
  echo "Failed to install Cask (Homebrew Extension)"
  exit 1
fi

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=4
INITBACKTITLE="Bootstrapping Your Mac"
INITTITLE="Rad AI Bootstrapping"
INITMENU="Welcome to the team! Please ask a teammate any questions you have as you go along! Choose what type of team member you are and we'll do some configuration of your Mac:"

OPTIONS=(1 "Technical Team Member"
         2 "Non-Technical Team Member")

CHOICE=$(dialog --clear \
                --backtitle "$INITBACKTITLE" \
                --title "$INITTITLE" \
                --menu "$INITMENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)
clear

case $CHOICE in
        1)
            echo "Cool! You're a technical team member!"
            ROLE="technical"
            BREW_CASKS_FOR_ROLE=(
                cheatsheet
                puppetlabs/puppet/puppet-agent
                sublime-text
                vagrant
                vagrant-manager
                virtualbox
            )
            ;;
        2)
            echo "Nice! You're a Non-Technical team member!"
            ROLE="nontechnical"
            BREW_CASKS_FOR_ROLE=()
            ;;
esac

if [ "$ROLE" == 'technical' ]; then
    DEFAULT_BREW_PACKAGES=(
        automake
        git
        findutils
        jq
        libjpeg
        libmemcached
        markdown
        memcached
        npm
        pulumi
        pyenv
        python
        tmux
        tree
        vim
        wget
    )

    ## allow for extension with role specific lists
    BREW_PACKAGES=(
        ${DEFAULT_BREW_PACKAGES[*]}
    )

    echo " Installing packages..."
    brew install ${BREW_PACKAGES[@]}

    DEFAULT_PYTHON_PACKAGES=(
        awscli
        pep8
        python-dateutil
        virtualenv
        virtualenvwrapper
    )

    ## allow for extension with role specific lists
    PYTHON_PACKAGES=(
        ${DEFAULT_PYTHON_PACKAGES[*]}
    )

    echo " Installing Python packages with pip3..."
    sudo pip3 install ${PYTHON_PACKAGES[@]}
fi


DEFAULT_CASKS=(
    dashlane
    google-chrome
    slack
    spectacle
)

CASKS=(
    ${DEFAULT_CASKS[*]}
    ${BREW_CASKS_FOR_ROLE[*]}
)

echo "About to install these casks: "
echo ${CASKS[@]}
brew cask install ${CASKS[@]}

echo " Cleaning up after installs..."
brew cleanup

echo "Configuring OSX..."
sudo -v
# echo "Set fast key repeat rate"
# defaults write NSGlobalDomain KeyRepeat -int 8

if [ "$ROLE" == 'technical' ]; then
    echo " Show filename extensions by default"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true

    echo " Finder: show hidden files by default"
    defaults write com.apple.finder AppleShowAllFiles -bool true

    echo " Finder: show all filename extensions"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true

    echo " Finder: show status bar"
    defaults write com.apple.finder ShowStatusBar -bool true
fi


###########################
#### OSX CONFIGURATION ####
###########################

# Dock Configuration
# echo " Automatically hide and show the Dock"
# defaults write com.apple.dock autohide -bool true

# echo " Remove genie animation"
# defaults write com.apple.dock mineffect suck;

# echo " Remove bouncing animation"
# defaults write com.apple.dock no-bouncing -bool true

# echo " show indicator lights for open applications in the Dock"
# defaults write com.apple.dock show-process-indicators -bool true

# echo " Put the dock on the left"
# defaults write com.apple.Dock orientation -string "left"

# echo " Use list view in all Finder windows by default"
# # Four-letter codes for the other view modes: icnv, clmv, Flwv"
# defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# echo " Enable tap-to-click"
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
# defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 6

# echo " Confirm natural scroll"
# defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

# echo " Write screenshots to pictures"
# defaults write com.apple.screencapture location ~/Pictures/Screenshots

echo " Remove all apps from the dock"
defaults write com.apple.dock persistent-apps -array

echo " Require password immediately after sleep or screen saver begins"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

echo " Confirm location services are on"
defaults write com.apple.locationd LocationServicesEnabled -int 1

echo " Confirming display will sleep at 14"
pmset -a displaysleep 14

sudo -v
# echo "Would you like to make a primary working directory?"
# select yn in "Yes" "No"; do
#     case $yn in
#         Yes ) select yn in "Yes" "No"; do
#             echo -n "What would you like it to be called? "
#             read dir_name
#             echo "Creating folder structure..."
#             [[ ! -d $dir_name ]] && mkdir ~/$dir_name;;
#         No ) exit;;
#     esac
# done

dialog --title "Make Directory?" --yesno "Would you like to make a primary working directory?" 7 60

response=$?
case $response in
   0)
        DIR_NAME=$(dialog --inputbox "Enter your desired directory name: " 8 60 --output-fd 1)
        [[ ! -d $DIR_NAME ]] && mkdir ~/$DIR_NAME
        echo "Nice, we made ${DIR_NAME}";;
   1) echo "File not deleted.";;
   255) echo "[ESC] key pressed.";;
esac



#######################
#### GITHUB CONFIG ####
#######################

if [ "$ROLE" == 'technical' ]; then
    SSH_KEYGEN=`which ssh-keygen`
    SSH=`which ssh`
    SSH_COPY_ID=`which ssh-copy-id`
    FILENAME=~/.ssh/github
    KEYTYPE=ecdsa
    KEYSIZE=521
    PASSPHRASE=$(dialog --inputbox "Enter a passphrase for your new github ssh key: " 8 60 --output-fd 1)
    $SSH_KEYGEN -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
    pbcopy < ~/.ssh/${FILENAME}.pub
    echo "Nice! We copied your ssh pub key to your clipboard for later use"
fi


###########################
#### MANUAL ONBOARDING ####
###########################

echo "Bootstrapping complete, let's step through the next steps with a checklist here, it'll require use of Chrome, so wait a sec and we'll open that... "
sleep 6
open -a "Google Chrome" https://certs.radai-systems.com --args --make-default-brows

MANUALITEMS=(
        1 "Install the RADAI certificates per instructions (you need both pem and cert)" off
        2 "Install a MFA app on your mobile device (Google Authenticator)" off
        3 "Log in to your Google Account on Chrome or GMail" off
        4 "Change your google account password" off
        5 "Confirm your Google Account has MFA switched on" off
        6 "Check your email from jumpcloud.com, follow instructions to change password and add MFA." off
        7 "Open the Dashlane App on your computer and create a login with your Rad AI email" off
        8 "Add Dashlane extension to Google Chrome" off
        9 "In Dashlane, add a new password called github_ssh, store your ssh passphrase there" off
        10 "Confirm Avast Security is running (expect free version, no password or vpn management)" off
        11 "Connect to RADAI Corporate Wifi using your JumpCloud Creds (first name, password)" off
        12 "Confirm your phone uses a passcode to unlock" off
        13 "Confirm your mobile device locks when idle" off
        14 "Confirm your mobile device idles after a maximum of 5 minutes" off
        15 "Confirm your mobile device is at Android 6.0 or iOS 8 or higher" off
        16 "Complete your HIPAA training! (it's fine to rerun this script if that takes a while)" off
        17 "Notify infrastructure admin that you have completed HIPAA training" off
    )

dialog --clear --checklist "Mark items complete with the spacebar!" 30 100 100 "${MANUALITEMS[@]}" --clear

## Manual Checklist
if [ "$ROLE" == 'technical' ]; then
    TECHNICAL_ITEMS=(
        1 "Add your radai email to you GitHub user or create a new account with your radai email" off
        2 "Add your github ssh key, which is already copied on your clipboard and lives at ~/.ssh/github.pub, to your GitHub user" off
        3 "Go to vpn.radai-systems.com" off
        4 "Install OpenVPN Client" off
        5 "Add MFA for OpenVPN" off
        6 "Connect to VPN via Toolbar, Connect, use JumpCloud Creds (first name, password)" off
    )

    dialog --clear --checklist "Technical team member manual checklist!" 20 100 100 "${TECHNICAL_ITEMS[@]}" --clear

    #########################
    ### Git Configuration ###
    #########################

    echo "Git setup begins!"

    echo " Enter your username for Git:";
    read GITUSER;
    git config --global user.name "${GITUSER}"

    echo " Enter the Global Email for Git:";
    read GITEMAIL;
    git config --global user.email "${GITEMAIL}"

    if [ ! -f ~/.gitignore ]; then
      touch ~/.gitignore
      echo '.DS_Store' >> ~/.gitignore
      echo '._*' >> ~/.gitignore
      echo 'Thumbs.db' >> ~/.gitignore
      echo '.Spotlight-V100' >> ~/.gitignore
      echo '.Trashes' >> ~/.gitignore
    fi

    echo "Git has been configured!"
    git config --list
fi

echo "Your setup is all done! You can rerun this script if needed."
