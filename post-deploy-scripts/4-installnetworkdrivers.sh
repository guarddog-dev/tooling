#!/bin/bash

#set -euo pipefail

#Install required utilities (should already be in OVA)
tdnf install -y pciutils usbutils > /dev/null 2>&1

PCIDEVICE=$(lspci | grep 'Network controller')
#If Wireless card is Intel, install linux-firmware and load the Intel Drivers
if [[ $PCIDEVICE == *"Intel"* ]]; 
then
	echo "  Installing PCI Network Drivers  ..."
	echo "   Discovered Intel Wireless Network Controller ..."
	  
	#Intel Only packages
	echo "   Installing Linux packages for Wireless Network Controller support ..."
	tdnf install -y git linux-firmware linux-api-headers linux-devel usbutils pciutils wpa_supplicant > /dev/null 2>&1 

	##Download and install Intel Firmware/Driver
	echo "   Downloading and Installing Wireless Network Controller Firmware/Drivers ..."
	cd /tmp
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git --depth 1 > /dev/null 2>&1
	cd linux-firmware
	sudo cp iwlwifi* /lib/firmware/
	  
	#probe for devices that need driver
	depmod -a > /dev/null 2>&1
	modprobe iwlwifi > /dev/null 2>&1
	  
	#Enable wifi service for new device
	echo "   Enabling Wireless Services ..."
	WLANSTATUS=$(systemctl is-active wpa_supplicant@wlan0.service)
	if [[ $WLANSTATUS == "inactive" ]]; 
	then
		systemctl enable wpa_supplicant@wlan0.service > /dev/null 2>&1
		systemctl start wpa_supplicant@wlan0.service > /dev/null 2>&1
	else
		systemctl enable wpa_supplicant@wlan1.service > /dev/null 2>&1
		systemctl start wpa_supplicant@wlan1.service > /dev/null 2>&1
	fi
fi
#dmesg | grep iwlwifi
#wpa_cli -i wlan0
#wpa_cli -i wlan1
#scan
#scan_results

USBDEVICE=$(lsusb | grep Realtek)
if [[ $USBDEVICE == *"RTL88x2bu"* ]]; 
then
	echo "  Installing USB Network Drivers  ..."
	echo "   Discovered Realtek RTL88x2bu Network Controller ..."
	  
	#Realtek RTL88x2bu Only packages
	echo "   Installing Linux packages for Wireless Network Controller support ..."
	tdnf install -y git linux-firmware linux-api-headers linux-devel usbutils pciutils wpa_supplicant dkms build-essential > /dev/null 2>&1

	##Download and install Realtek RTL88x2bu Firmware/Driver
	echo "   Downloading and Installing Wireless Network Controller Firmware/Drivers ..."
	cd /tmp
	git clone https://github.com/morrownr/88x2bu-20210702.git
	cd /tmp/88x2bu-20210702

	#make installer
	make clean > /dev/null 2>&1
	make > /dev/null 2>&1
	sudo make install > /dev/null 2>&1

	#update config options
	sed -i 's/options 88x2bu rtw_drv_log_level=0 rtw_led_ctrl=1 rtw_vht_enable=1 rtw_power_mgnt=1 rtw_switch_usb_mode=0/options 88x2bu rtw_drv_log_level=0 rtw_led_ctrl=1 rtw_vht_enable=1 rtw_power_mgnt=0 rtw_switch_usb_mode=2/g' /etc/modprobe.d/88x2bu.conf
	  
	#probe for devices that need driver
	depmod -a > /dev/null 2>&1
	modprobe 88x2bu > /dev/null 2>&1
	  
	#Enable wifi service for new device
	echo "   Enabling Wireless Services ..."
	WLANSTATUS=$(systemctl is-active wpa_supplicant@wlan0.service)
	if [[ $WLANSTATUS == "inactive" ]]; 
	then
		systemctl enable wpa_supplicant@wlan0.service > /dev/null 2>&1
		systemctl start wpa_supplicant@wlan0.service > /dev/null 2>&1
	else
		systemctl enable wpa_supplicant@wlan1.service > /dev/null 2>&1
		systemctl start wpa_supplicant@wlan1.service > /dev/null 2>&1
	fi
fi
#dmesg | grep 88x2bu
#wpa_cli -i wlan0
#wpa_cli -i wlan1
#scan
#scan_results

