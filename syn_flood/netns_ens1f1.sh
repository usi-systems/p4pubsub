#!/bin/bash
sudo ip netns delete ns_ens1f1
sudo ip netns add ns_ens1f1
sudo ip link set ens1f1 netns ns_ens1f1
sudo ip netns exec ns_ens1f1 ip addr add dev ens1f1 192.168.1.104/24
sudo ip netns exec ns_ens1f1 ip link set dev ens1f1 up

# Add the arp for the other local port
#sudo ip netns exec ns_ens1f1 arp -s 192.168.1.103 ec:0d:9a:6d:e3:d8

# Add the arp for the remote ports
#sudo ip netns exec ns_ens1f1 arp -s 192.168.1.101 3c:fd:fe:a6:7e:a8
sudo ip netns exec ns_ens1f1 arp -s 192.168.1.102 ec:0d:9a:7e:90:43
