#!/bin/bash

##Prep
echo "  Prepping GuardDog Deployment ..."
lastreleaseversion() { git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$1" | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 2; }

#Create Folders
echo "   Creating Folders ..."
mkdir /etc/guarddog
mkdir /etc/guarddog/opt
mkdir /etc/guarddog/logs
mkdir /etc/guarddog/rtl
mkdir /etc/guarddog/keys
mkdir /etc/guarddog/op
mkdir /etc/guarddog/config_files
mkdir /etc/guarddog/scripts
mkdir /etc/guarddog/gunicorn

#Install Drivers
echo "   Installing Drivers ..."
cd /tmp
git clone https://github.com/morrownr/88x2bu-20210702.git > /dev/null 2>&1
cd 88x2bu-20210702
./install-driver.sh > /dev/null 2>&1
