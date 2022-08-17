#!/bin/bash

##Prep
echo "  Prepping GuardDog Deployment ..."
lastreleaseversion() { git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$1" | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 2; }

#Install remote.it
echo "   Installing remote.it ..."
R3_VERSION="4.14.8" R3_REGISTRATION_CODE="5CD7194D-31DA-4B86-8523-B8B582C667F2" sh -c "$(curl -L https://downloads.remote.it/remoteit/install_agent.sh)" > /dev/null 2>&1
sudo systemctl enable remoteit@.service
#to check service
#sudo systemctl status remoteit@*

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

#Move service account file
mv /root/setup/service-account.json /etc/guarddog/keys/service-account.json

#Set environment settings
echo "   Setting Environment Variable ..."
echo 'DEV' > /etc/guarddog/opt/env

#Install Drivers
echo "   Installing Drivers ..."
cd /tmp
git clone https://github.com/morrownr/88x2bu-20210702.git > /dev/null 2>&1
cd 88x2bu-20210702
./install-driver.sh > /dev/null 2>&1

#Install dkms
echo "   Installing dkms ..."
tdnf install -y dkms > /dev/null 2>&1

#Install Google SDK
echo "   Installing Google SDK ..."
GCLOUDCLIVERSION="397.0.0"
mkdir -p /usr/local/gcloud
cd /tmp
wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUDCLIVERSION}-linux-x86_64.tar.gz > /dev/null 2>&1
mv google-cloud-cli-${GCLOUDCLIVERSION}-linux-x86_64.tar.gz google-cloud-sdk.tar.gz
tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz > /dev/null 2>&1
/usr/local/gcloud/google-cloud-sdk/install.sh --override-components gcloud --usage-reporting false --path-update true --rc-path /root/.bashrc --quiet > /dev/null 2>&1
rm -rf /tmp/google-cloud-sdk.tar.gz
source /usr/local/gcloud/google-cloud-sdk/path.bash.inc

#Link gcloud to bin
ln -s \
  /usr/local/gcloud/google-cloud-sdk/bin/gcloud \
  /usr/local/bin/

#Install gcloud Docker-Credential-GCR
echo "   Installing Google SDK Docker-Credential-GCR..."
/usr/local/gcloud/google-cloud-sdk/bin/gcloud components install docker-credential-gcr --quiet > /dev/null 2>&1

#Link docker-credential-gcloud to bin
ln -s \
  /usr/local/gcloud/google-cloud-sdk/bin/docker-credential-gcloud \
  /usr/local/bin/

#Auth Activate
echo "   Auth Activating Google SDK ..."
/usr/local/gcloud/google-cloud-sdk/bin/gcloud auth activate-service-account vm-service@guarddog-dev.iam.gserviceaccount.com --key-file="/etc/guarddog/keys/service-account.json" > /dev/null 2>&1

#Set Gcloud Project
echo "   Setting Google SDK Project ..."
echo "y" | /usr/local/gcloud/google-cloud-sdk/bin/gcloud config set project guarddog-dev > /dev/null 2>&1

#Authorize Docker with Google SDK
echo "   Authorizing Docker with Google SDK ..."
/usr/local/gcloud/google-cloud-sdk/bin/gcloud auth configure-docker --quiet > /dev/null 2>&1

#Pull Docker Image
echo "   Pulling Docker Image ..."
docker pull gcr.io/guarddog-dev/dfido:vm-1.0.0 > /dev/null 2>&1

#Remove json
rm /etc/guarddog/keys/service-account.json
