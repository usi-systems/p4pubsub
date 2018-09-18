#!/bin/bash
sudo rm *.pcap
sudo rm -rf /tmp/mininet/*
sudo mn -c
sudo rm gen.json
p4c-bm2-ss --p4v 14 ruby_g.p4 -o gen.json
sudo python  ~/cdn_pub_sub/bmv2_mininet/multi_switch_mininet.py --log-dir "/tmp/mininet" --manifest ./p4app.json --target "multiswitch" --auto-control-plane --behavioral-exe ~/behavioral-model/targets/simple_switch/simple_switch --json ./gen.json

