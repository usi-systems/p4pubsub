# Overview

This is the experiment for the NSDI20 submission.

We used the following topology:

    node96  <--->
    node97  <--->  tofino1  <--->  tofino2 <---> node95
    node98  <--->

where nodes 97 and 98 are clients, node96 is the forwarder, and node95 is the
publisher. The hicn-plugin (VPP) runs on all nodes.


# Setup

To be setup on each node.

## Dependencies

Follow: https://wiki.fd.io/view/HICN


### Install VPP

From packages:

    curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | sudo bash
    sudo apt-get update
    sudo apt-get install libvppinfra libvppinfra-dev vpp vpp-dev vpp-plugin-core vpp-plugin-dpdk

Or, alternately, from source:

    git clone https://gerrit.fd.io/r/vpp
    cd vpp
    git co stable/1908
    build-root/vagrant/build.sh
    sudo dpkg -i build-root/*.deb

### Libmemif

    cd vpp/build-root
    git co stable/1908
    mkdir build-libmemif
    cd build-libmemif
    cmake ../../extras/libmemif/ -DCMAKE_INSTALL_PREFIX=/usr
    make && sudo make install

## Install HICN

You can try installing using packages:

    curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | sudo bash
    sudo apt-get install hicn-light hicn-utils hicn-apps hicn-plugin

Or from source:

   sudo apt-get install python3-ply libconfig-dev libasio-dev
   #git clone https://git.fd.io/hicn 
   git clone -b camus git@github.com:usi-systems/hicn.git
   cd hicn
   mkdir build
   cd build
   cmake -DBUILD_HICNPLUGIN=ON -DBUILD_APPS=ON -DCMAKE_INSTALL_PREFIX=/usr ..
   make -j8
   sudo make install

### Disable CS

For the forwarder on the client machines, the CS (content store) should be
disabled. This will ensure all client requests get sent out to the network,
giving the illusion that the clients are on separate machines.

    vim hicn-plugin/src/params.h

And set `HICN_FEATURE_CS 0`, then compile.

## Running 

Follow: https://github.com/FDio/hicn/tree/master/hicn-plugin

In the VPP config file, enable the CLI sock:
    
    unix {
      ...
      cli-listen /run/vpp/cli.sock
      ... }

You can find the DPDK device id by running:

    sudo lshw -c network -businfo

Start VPP:

    sudo vpp -c /etc/vpp/startup.conf

Then, from another shell, run `sudo vppctl` to configure hICN. e.g. on node96:

    $ sudo vppctl
        _______    _        _   _____  ___ 
     __/ __/ _ \  (_)__    | | / / _ \/ _ \
     _/ _// // / / / _ \   | |/ / ___/ ___/
     /_/ /____(_)_/\___/   |___/_/  /_/    
    
    vpp# show int
                  Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count     
    TenGigabitEthernet1/0/0           1     down         9000/0/0/0     
    local0                            0     down          0/0/0/0       
    vpp# set int state TenGigabitEthernet1/0/0 up
    vpp# set interface ip address TenGigabitEthernet1/0/0 9001::6/64
    vpp# hicn control param cs size 8192
    vpp# hicn control start
    hicn: fwdr initialize => Ok
    vpp# hicn punting add prefix b001::/64 intfc TenGigabitEthernet1/0/0 type ip
    vpp# hicn punting add prefix c000::/8 intfc TenGigabitEthernet1/0/0 type ip
    vpp# hicn show
    Forwarder: enabled
      PIT:: max entries:131072, lifetime default: 20.00 sec (min:0.200, max:20.00)
      CS::  max entries:8192, network entries:4096, app entries:4096 (allocated 0, free 4096)
      PIT entries (now): 0
      CS total entries (now): 0, network entries (now): 0
      Forwarding statistics:
        pkts_processed: 0
        pkts_interest_count: 0
        pkts_data_count: 0
        pkts_from_cache_count: 0
        interests_aggregated: 0
        interests_retransmitted: 0
    Faces: 0
    Strategies:
    (0) Static Weights: weights are updated by the control plane, next hop is the one with the maximum weight.
    (1) Round Robin: next hop is chosen ciclying between all the available next hops, one after the other.
    vpp# hicn face show
    vpp# hicn face ip add local 9001::6 remote 9001::5 intfc TenGigabitEthernet1/0/0
    Face id: 0
    vpp# hicn fib add prefix b001::/64 face 0
    vpp# hicn fib add prefix c000::/8 face 0


### Setup Tofinos

Compile the hicn program following the instructions in `../README.md`

Edit the PTF `test.py` for each tofino, and adjust the `self.mac_tbl` to match
the MAC/port mapping in your setup.

Launch bfswitchd, bring up the ports using `tofinoX.ports.txt`, and run the PTF
test. Make sure to copy the coresponding `tofinoX.rules.txt` into
`hicn-tofino/ptf-tests/hicn/`.

### Publisher

Start VPP on the publisher (node95), and configure it with vppctl. Then launch
`hiperf` for the stream, and `kv-store` for the "cold" content:

    sudo hiperf -S b001::1/128
    sudo kv-store -c 10000 -m 1200 -P c000


### Forwarder

Just launch VPP and configure it.


### Clients

First, on both clients, launch VPP and configure it.

On one client start pulling the stream:

    sudo hiperf -C b001::1 -W 220

On another, start the pulling the "cold" content:

    sudo hiclients http://webserver/hi -o baseline_lats.tsv -C 15 -c 100000 -j64

Plot the results:

    cat camus_lats.tsv | ~/s/bin-tsv - 4000 > camus.tsv
    cat baseline_lats.tsv | ~/s/bin-tsv - 4000 > baseline.tsv
    ~/s/cdf.py baseline.tsv Baseline camus.tsv Camus


## IPv6 Misc

Set interface address:

    sudo ifconfig eth3 add 9002::3/64

Add static ARP rule:

    sudo ip -6 neigh add 9001::3 lladdr 00:11:22:33:44:55 nud permanent dev eth1

Remove a static ARP rule:

    sudo ip -6 neigh del 9001::3  dev eth1
