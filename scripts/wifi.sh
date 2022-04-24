#!/bin/bash
nmcli device wifi list
read -p "SSID: " SSID
read -p "Password: " password
nmcli device wifi connect "$SSID" password $password
nmcli connection show