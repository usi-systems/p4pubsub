#!/bin/bash

IFACE=eth21
HOST_ID=97

sudo ifconfig $IFACE up 10.0.0."$HOST_ID"
sudo ifconfig $IFACE mtu 9700

sudo arp -s 10.0.0.97 0c:c4:7a:ba:c6:ad
sudo arp -s 10.0.0.98 98:03:9b:67:f5:ee

ip route get 10.0.0.98
