#!/bin/bash

#Provision System
echo -e "\e[92m   Provisioning System ..." > /dev/console

#execute run fido automation
cd /root/automation
./1-run_vm_fido.sh.x > /dev/console


