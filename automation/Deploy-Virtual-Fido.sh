#!/bin/bash

#Provision System
echo -e "\e[92m   Provisioning System ..." > /dev/console

#execute run fido automation
cd /root/automation

#Docker Method - Depricated
#./1-run_vm_fido.sh > /dev/console 

#Build Kubernetes Cluster and deploy vFido
./build-virtual-fido.sh > /dev/console

