#!/bin/bash

set -e

source .bash_aliases

shopt -s expand_aliases

if ! sudo -l | grep -q NOPASSWD; then

	echo "Please first run script with sudo so you will NOT be prompted with a password"

	exit 1

fi

if [[ "$(whoami)" == "root" ]]; then

	ORIG_USER=$SUDO_USER

	if ! sudo -l -U $ORIG_USER | grep -q NOPASSWD; then

		echo "$ORIG_USER ALL=(ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

		echo "Password now not needed for sudo."

		echo "Please exit the terminal session."

		exit 0

	else

		echo-red "Do NOT run with sudo or as root!";

		echo-white "Remove sudo or log in as regular user."

		exit 1;

	fi

fi

if ! sudo -v; then

	echo-red "No sudo privileges. Root access required!";

	exit 1;

fi

if ! uname -a | grep -q Ubuntu; then

	if ! uname -a | grep -q pop-os; then

		echo-red "This script is for an Ubuntu based distribution!"

		exit 1

	fi

fi

if ! pwd | grep -q '/repos/cbc-development-setup'; then

	echo-red "This repo's location is incorrect!"

	echo-white "

Run the following commands:

    cd ~
    mkdir repos
    cd repos
    git clone https://github.com/CaneBayComputers/cbc-development-setup.git
    cd cbc-development-setup
    ./install.sh

"

	exit 1

fi

if ! [ -f ~/.bash_aliases ]; then

	echo "source ~/repos/cbc-development-setup/.bash_aliases" > ~/.bash_aliases

else

	if ! cat ~/.bash_aliases | grep cbc-development-setup; then

		echo "source ~/repos/cbc-development-setup/.bash_aliases" >> ~/.bash_aliases

	fi

fi

clear

echo; echo

echo "
              WELCOME TO THE CBC DEV INSTALLER !

Leave answers blank if you do not know the info. You can re-run the
installer to enter in new info when have it.

After the installer is finished open the pre-installed web browser,
look at the bookmarks bar and select the cbc-laravel-php 7 or 8
bookmark. You can also view the database with cbc-phpmyadmin bookmark.

The pages can be edited in Sublime Text which is pre-installed as
well. In ST you should see the two Laravel folders. Open the
corresponding folder and go to app > resources > views > content. Here
you will see the examples pages. Pages are created by naming them:
page-name.blade.php
Creating a sub-folder will also correspond to a link folder such as:
http://cbc-laravel-php8/sub-folder/page-name"



###############################
# Set up git committer info
###############################

echo

echo-cyan 'Git config settings ...'

echo-white

git config --global diff.tool meld

git config --global mergetool.keepBackup false

if ! git config user.name; then

	echo-yellow -ne 'Enter your full name for Git commits: '

	echo-white -ne

	read GIT_NAME

	if ! [ -z "${GIT_NAME}" ]; then

		git config --global user.name "$GIT_NAME"

		sudo git config --global user.name "$GIT_NAME"

	fi

	echo

fi

if ! git config user.email; then

	echo-yellow -ne 'Enter your email address for Git commits: '

	echo-white -ne

	read GIT_EMAIL

	if ! [ -z "${GIT_EMAIL}" ]; then

		git config --global user.email $GIT_EMAIL

		sudo git config --global user.email $GIT_EMAIL

	fi

	echo

fi

if ! [ -f ~/.ssh/id_rsa ]; then

  if ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa; then true; fi

  echo

  echo-blue 'Copy and paste the following into your Github account under Settings > SSH and GPG keys:'

  echo-white

  cat ~/.ssh/id_rsa.pub

  echo ; echo

  read -n 1 -r -s -p $'Press enter to continue...\n'

  echo ; echo

fi

echo-green "Git configured!"

echo-white

echo



###############################
# Set S3FS credentials
###############################

echo-yellow 'Enter your AWS credentials.'

echo-yellow -ne 'Access ID: '

read S3_ACCESS_ID

echo-yellow -ne 'Secret Key: '

read S3_SECRET_KEY

echo-white -ne

if ! [ -z "${S3_ACCESS_ID}" ]; then

	echo $S3_ACCESS_ID:$S3_SECRET_KEY > ~/.passwd-s3fs

	chmod 600 ~/.passwd-s3fs

fi

echo-white

echo



###############################
# Initial update and package installations
###############################

echo-cyan 'Updating and installing initial packages ...'

echo-white

sudo apt-get update -y

sudo apt-get -y install ca-certificates curl python3-pip python3-venv figlet mariadb-client apt-transport-https gnupg lsb-release s3fs acl

echo

echo



###############################
# AWS
###############################

echo-cyan 'Installing AWS ...'

mkdir -p ~/s3

echo-white

if ! aws --version > /dev/null 2>&1; then

	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" > awscli-bundle.zip

	unzip -o awscli-bundle.zip

	rm -f awscli-bundle.zip

	sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

	rm -fR aws

fi

echo

echo-green "AWS installed!"

echo-white

echo

echo-cyan 'Configuring AWS ...'

echo-white

if aws configure get default.region; then

	aws configure set default.region us-east-1

fi

if aws configure get default.output; then

	aws configure set default.output json

fi

if ! [ -z "${S3_ACCESS_ID}" ]; then

	aws configure set aws_access_key_id $S3_ACCESS_ID

	aws configure set aws_secret_access_key $S3_SECRET_KEY

fi

echo-green "AWS configured!"

echo-white

echo



###############################
# Docker
###############################

echo

echo-cyan 'Installing Docker ...'

echo-white

for PKG in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do

	if sudo apt-get purge $PKG > /dev/null 2>&1; then true; fi

done

if ! [ -f /etc/apt/sources.list.d/docker.list ]; then

  sudo install -m 0755 -d /etc/apt/keyrings

  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y -q

fi

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo

echo-green "Docker installed!"

echo-white



###############################
# PHP / NPM
###############################

echo

echo-cyan 'Installing PHP ...'

echo-white

sudo apt-get -y install php php-bcmath php-cli php-common php-curl php-mbstring php-zip php-xml

echo

echo-cyan 'Installing NPM ...'

echo-white

if ! nodejs --version > /dev/null 2>&1; then

	sudo apt-get -y install nodejs

fi

if ! npm --version > /dev/null 2>&1; then

	sudo apt-get -y install npm

fi

echo

echo-cyan 'Cleaning up ...'

echo-white

sudo apt-get -y -q autoremove

echo



###############################
# Create Docker volume
###############################

echo

echo-cyan 'Creating Docker volume ...'

echo-white

if ! sudo docker volume ls | grep vol-cbc-docker-stack; then

  sudo docker volume create vol-cbc-docker-stack

fi

echo

echo-green "Docker volume created!"

echo-white



###############################
# Composer
###############################

echo

echo-cyan 'Installing Composer ...'

echo-white

if ! composer --version > /dev/null 2>&1; then

	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

	sudo php composer-setup.php --install-dir=/usr/bin --filename=composer

	rm -f composer-setup.php

fi

echo

echo-green "Composer installed!"

echo-white

echo



###############################
# Hosts
###############################
echo-cyan 'Writing domain names to hosts file ...'

echo-white

while read HOST; do

	if ! cat /etc/hosts | grep "$HOST"; then

		echo "$HOST" | sudo tee -a /etc/hosts

	fi

done < hosts.txt

echo



###############################
# Fonts
###############################

sudo cp -f ANSI\ Regular.flf /usr/share/figlet



###############################
# Repos
###############################

echo-cyan 'Installing repos ...'

echo-white

cd ~

mkdir -p repos

cd repos

REPOS=( certbot-bash-wrapper cbc-docker-stack cbc-laravel-php7 cbc-laravel-php8 )

for REPO in "${REPOS[@]}"

do

	printf "\n------- $REPO\n"

	if [ ! -d $REPO ]; then

		git clone https://github.com/CaneBayComputers/$REPO.git

	else

		cd $REPO

		git pull

		cd ..

	fi

done

echo

upcbcstack

sleep 5



###############################
# Set up Laravel repos
###############################

echo-cyan 'Setting up CBC Laravel PHP7...'

echo-white

repos

cd cbc-laravel-php7

source ./install.sh --dev

echo


echo-cyan 'Setting up CBC Laravel PHP8...'

echo-white

repos

cd cbc-laravel-php8

source ./install.sh --dev

cd ..

echo



###############################
# Yay all done
###############################

touch ~/repos/cbc-development-setup/is_installed