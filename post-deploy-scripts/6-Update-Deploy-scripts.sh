#!/bin/bash

#set -euo pipefail

echo "  Updating Deployment Processes  ..."

# Run Repo Script post install

# Variables
REPO="https://github.com/guarddog-dev"
REPONAME="tooling"
REPOFOLDER="automation"

#Download Repo Folder
echo "   Downloading Repo Folder ..."
git clone --filter=blob:none --sparse ${REPO}/${REPONAME}
cd ${REPONAME}
git sparse-checkout init --cone
git sparse-checkout add ${REPOFOLDER}
cd ${REPOFOLDER}
CURRENTPATH=$(pwd)
chmod +x *.sh

#Update Automation Scripts
echo "   Replacing Deployment Automation ..."
#mv *.* /root/automation/.
find $CURRENTPATH/ -maxdepth 1 -type f -print0 | xargs -0 mv -t /root/automation
#mkdir /root/automation/dist
#mv provisioning /root/automation/dist/provisioning 

#Cleanup
echo "   Cleaning up Repo Download ..."
cd ${CURRENTPATH}
rm -rf *
cd ..
rmdir --ignore-fail-on-non-empty *
rm -rf .*
rm -rf *
cd ..
rmdir ${REPONAME}

