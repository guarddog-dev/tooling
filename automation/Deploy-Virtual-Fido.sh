#!/bin/bash

#Provision System
echo "  Provisioning System ..."
#create dist folder
mkdir /root/automation/dist
#move provisioning file to dist folder
mv /root/automation/provisioning /root/automation/dist/provisioning
#execute run fido automation
. /root/automation/1-run_vm_fido.sh.x


