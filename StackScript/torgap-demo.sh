#!/bin/bash

#  torgap-demo.sh - Installs torgap-demo behind a tor address derived from a minisign secret key
#  Key conversion is made by torgap-sig-cli-rust.
#  Once set up, onion service offers to download and verify a signed text file.
#
#  Created by @gorazdko 2020-11-19
#
#  https://github.com/BlockchainCommons/torgap-demo
#  https://github.com/BlockchainCommons/torgap-sig-cli-rust
#
#  Based on LinodeStandUp.sh by Peter Denton
#  source: https://github.com/BlockchainCommons/Bitcoin-Standup-Scripts/blob/master/Scripts/LinodeStandUp.sh


# It is highly recommended to add a Tor V3 pubkey for cookie authentication.
# It is also recommended to delete the /standup.log, and
# /standup.err files.

# torgap-demo.sh sets Tor and torgap-demo as systemd services so that they
# start automatically after crashes or reboots. If you supply a SSH_KEY in
# the arguments it allows you to easily access your node via SSH using your rsa
# pubkey, if you add SYS_SSH_IP's it will only accept SSH connections from those
# IP's.

# torgap-demo.sh will create a user called standup, and assign the optional
# password you give it in the arguments.

# torgap-demo.sh will create two logs in your root directory, to read them run:
# $ cat standup.err
# $ cat standup.log

# This block defines the variables the user of the script needs to input
# when deploying using this script.
#
# <UDF name="torV3AuthKey" Label="x25519 Public Key" default="" example="descriptor:x25519:JBFKJBEUF72387RH2UHDJFHIUWH47R72UH3I2UHD" optional="true"/>
# PUBKEY=
# <UDF name="userpassword" label="StandUp Password" example="Password to for the standup non-privileged account." />
# USERPASSWORD=
# <UDF name="ssh_key" label="SSH Key" default="" example="Key for automated logins to standup non-privileged account." optional="true" />
# SSH_KEY=
# <UDF name="sys_ssh_ip" label="SSH-Allowed IPs" default="" example="Comma separated list of IPs that can use SSH" optional="true" />
# SYS_SSH_IP=
# <UDF name="region" label="Timezone" oneOf="Asia/Singapore,America/Los_Angeles" default="America/Los_Angeles" example="Servers location" optional="false"/>
# REGION=
# <UDF name="minisign_key" label="Minisign Secret Key" default="" example="If no key supplied, it will be generated randomly" optional="true" />
# MINISIGN_KEY=
# <UDF name="minisign_secret_key_password" label="Password of/for Minisign Secret Key." default="" example="Password used to encrypt/decrypt minisign secret key" optional="true" />
# MINISIGN_SECRET_KEY_PASSWORD=


TOR_SECRET_KEY=/home/standup/.rsign/hs_ed25519_secret_key
TOR_PUBLIC_KEY=/home/standup/.rsign/hs_ed25519_public_key
TOR_HOSTNAME=/home/standup/.rsign/hostname

MINISIGN_SECRET_KEY=/home/standup/.rsign/rsign.key


# Force check for root, if you are not logged in as root then the script will not execute
if ! [ "$(id -u)" = 0 ]
then

  echo "$0 - You need to be logged in as root!"
  exit 1
  
fi

# Output stdout and stderr to ~root files
exec > >(tee -a /root/standup.log) 2> >(tee -a /root/standup.log /root/standup.err >&2)

####
# 2. Update Timezone
####

# Set Timezone

echo "$0 - Set Time Zone to $REGION"

echo $REGION > /etc/timezone
cp /usr/share/zoneinfo/${REGION} /etc/localtime

####
# 3. Bring Debian Up To Date
####

echo "$0 - Starting Debian updates; this will take a while!"

# Make sure all packages are up-to-date
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

# Install haveged (a random number generator)
apt-get install haveged -y

# Install GPG
apt-get install gnupg -y

apt-get install -y cmake build-essential

# Set system to automatically update
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
apt-get -y install unattended-upgrades

echo "$0 - Updated Debian Packages"

# get uncomplicated firewall and deny all incoming connections except SSH
sudo apt-get install ufw -y
ufw allow ssh
ufw enable

####
# 4. Set Up User
####

# Create "standup" user with optional password and give them sudo capability
/usr/sbin/useradd -m -p `perl -e 'printf("%s\n",crypt($ARGV[0],"password"))' "$USERPASSWORD"` -g sudo -s /bin/bash standup
/usr/sbin/adduser standup sudo

echo "$0 - Setup standup with sudo access."

# Setup SSH Key if the user added one as an argument
if [ -n "$SSH_KEY" ]
then

   mkdir ~standup/.ssh
   echo "$SSH_KEY" >> ~standup/.ssh/authorized_keys
   chown -R standup ~standup/.ssh

   echo "$0 - Added .ssh key to standup."

fi

# Setup SSH allowed IP's if the user added any as an argument
if [ -n "$SYS_SSH_IP" ]
then

  echo "sshd: $SYS_SSH_IP" >> /etc/hosts.allow
  echo "sshd: ALL" >> /etc/hosts.deny
  echo "$0 - Limited SSH access."

else

  echo "$0 - WARNING: Your SSH access is not limited; this is a major security hole!"

fi

mkdir ~standup/.rsign


apt-get install -y sharutils python

# script to handle white spaces in $MINISIGN_KEY correctly
sudo cat > ~standup/.rsign/script.py << EOF
import sys
s=sys.argv[1]

for i in range(len(s)):
    if s[i].isspace():
        last_char_index = i

print s[:last_char_index] + '\n' + s[last_char_index+1:];

EOF

# dump minisign secret key to file if provided
if [ -n "$MINISIGN_KEY" ]
then
   pushd ~standup/.rsign
   # Replace the last white space with new line
   TXT=$(python script.py "$MINISIGN_KEY")
   echo "$TXT" >> rsign.key
   popd
   echo "$0 - Added .rsign key to standup."
fi


chown -R standup ~standup/.rsign


###### install rust and cargo
cd $HOME
apt-get install -y git curl
curl https://sh.rustup.rs -sSf > rust_install.sh
chmod +x rust_install.sh
./rust_install.sh -y
export PATH=$HOME/.cargo/bin:$PATH


###### Install torgap-demo
cd ~standup
git clone https://github.com/BlockchainCommons/torgap-demo.git
pushd torgap-demo
cargo build --release
popd
chown -R standup torgap-demo

###### Install torgap-sig-cli-rust to convert minisign secret key to Tor secret key
git clone https://github.com/BlockchainCommons/torgap-sig-cli-rust.git
pushd torgap-sig-cli-rust

if [ -z "$MINISIGN_KEY" ]
then
   cargo run generate -s $MINISIGN_SECRET_KEY <<< $MINISIGN_SECRET_KEY_PASSWORD <<< $MINISIGN_SECRET_KEY_PASSWORD
   echo "$0 - minisign secret key generated"
fi

# generate DID document and expose it on our server
cargo run generate-did -s $MINISIGN_SECRET_KEY <<< $MINISIGN_SECRET_KEY_PASSWORD
cp ~standup/.rsign/did.json ~standup/torgap-demo/public/.well-known/did.json

echo "$0 - exporting keys to Tor format"
cargo run export-to-onion-keys -s $MINISIGN_SECRET_KEY <<< $MINISIGN_SECRET_KEY_PASSWORD
popd

chown -R standup torgap-sig-cli-rust

# Setup torgap-demo as a service
echo "$0 - Setting up torgap-demo as a systemd service."

# we need torgap-demo path. The script executed is in torgap-demo/StackScript
sudo cat > /etc/systemd/system/torgap-demo.service << EOF
[Unit]
Description=Demo server of an object signed by onion service
After=tor.service
Requires=tor.service

[Service]
Type=simple
Restart=always
ExecStart=/home/standup/torgap-demo/target/release/torgap-demo

[Install]
WantedBy=multi-user.target

EOF

# Create a text object to be signed with MINISIGN_SECRET_KEY
echo "This message is signed by the controller of the same private key used by $(<$TOR_HOSTNAME)" > ~standup/torgap-demo/public/text.txt 

echo "$0 - Signing our text object with minisign secret key"
~standup/torgap-sig-cli-rust/target/debug/rsign sign ~standup/torgap-demo/public/text.txt -s "$MINISIGN_SECRET_KEY" -t $(<$TOR_HOSTNAME) <<< $MINISIGN_SECRET_KEY_PASSWORD

# set our onion address in our index.html
sed -i -e "s/cargo run verify text.txt.*/cargo run verify text.txt --onion-address $(<$TOR_HOSTNAME) /g" ~standup/torgap-demo/public/index.html

####
# 5. Install latest stable tor
####

# Download tor

#  To use source lines with https:// in /etc/apt/sources.list the apt-transport-https package is required. Install it with:
sudo apt install apt-transport-https -y

# We need to set up our package repository before you can fetch Tor. First, you need to figure out the name of your distribution:
DEBIAN_VERSION=$(lsb_release -c | awk '{ print $2 }')

# You need to add the following entries to /etc/apt/sources.list:
cat >> /etc/apt/sources.list << EOF
deb https://deb.torproject.org/torproject.org $DEBIAN_VERSION main
deb-src https://deb.torproject.org/torproject.org $DEBIAN_VERSION main
EOF

# Then add the gpg key used to sign the packages by running:
sudo curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
sudo gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

# Update system, install and run tor as a service
sudo apt update -y
sudo apt install tor deb.torproject.org-keyring -y

# Setup hidden service

sed -i -e 's/#ControlPort 9051/ControlPort 9051/g' /etc/tor/torrc

sed -i -e 's/#CookieAuthentication 1/CookieAuthentication 1/g' /etc/tor/torrc

if grep -q "torgap-demo" /etc/tor/torrc; then
  echo "[error] /etc/tor/torrc: torgap-demo section already there. Remove it manually if you want to re-install the service."
  exit 1
fi

sed -i -e 's/## address y:z./## address y:z.\
\
HiddenServiceDir \/var\/lib\/tor\/torgap-demo\/\
HiddenServiceVersion 3\
HiddenServicePort 80 127.0.0.1:5557/g' /etc/tor/torrc

mkdir /var/lib/tor/torgap-demo
chown -R debian-tor:debian-tor /var/lib/tor/torgap-demo
chmod 700 /var/lib/tor/torgap-demo

## copy Tor secret key to the hidden service folder
cp $TOR_SECRET_KEY /var/lib/tor/torgap-demo/hs_ed25519_secret_key
cp $TOR_PUBLIC_KEY /var/lib/tor/torgap-demo/hs_ed25519_public_key
cp $TOR_HOSTNAME /var/lib/tor/torgap-demo/hostname

# Add standup to the tor group
sudo usermod -a -G debian-tor standup

echo "$0 - Starting torgap-demo service"
systemctl daemon-reload
systemctl enable torgap-demo.service
systemctl start torgap-demo.service

sudo systemctl restart tor.service


# add V3 authorized_clients public key if one exists
if ! [[ $PUBKEY == "" ]]
then

  # create the directory manually in case tor.service did not restart quickly enough
  mkdir /var/lib/tor/standup/authorized_clients

  # Create the file for the pubkey
  sudo touch /var/lib/tor/standup/authorized_clients/fullynoded.auth

  # Write the pubkey to the file
  sudo echo $PUBKEY > /var/lib/tor/standup/authorized_clients/fullynoded.auth

  # Restart tor for authentication to take effect
  sudo systemctl restart tor.service

  echo "$0 - Successfully added Tor V3 authentication"

else

  echo "$0 - No Tor V3 authentication, anyone who gets access may see your service"

fi

echo "Onion service up and running: $(</var/lib/tor/torgap-demo/hostname)"

# Finished, exit script
exit 0
