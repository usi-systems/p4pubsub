# INT Filtering Experiment

## Setup DPDK and NICs

Extract the dpdk source dir, set the ENV, and run `dpdk-setup.sh`:

    cd ~/dpdk-17.11
    cat env.sh
    export RTE_TARGET=x86_64-native-linuxapp-gcc
    export RTE_SDK=$HOME/dpdk-17.11
    source env.sh
    sudo ~/dpdk-17.11/usertools/dpdk-setup.sh

Build DPDK (option 14):

    [14] x86_64-native-linuxapp-gcc

Install NIC driver module:

    [17] Insert IGB UIO module

Install KNI module:

    [19] Insert KNI module

Setup hugetables:

    [21] Setup hugepage mappings for NUMA systems

Add NICs to driver:

    [23] Bind Ethernet/Crypto device to IGB UIO module


Edit `main.c` and ensure the NIC link settings are correct:

    cd p4pubsub/int/tools/dpdk_sender
    vim main.c

Then, build the tool:

    make

## Sending Packets

Send 10M packets with `remaining_hop_cnt` set to `4`, of which 1% should match
the filter:

    sudo ./build/main -l 0 -w 01:00.0 -- -P 1234 -c 10000000 -n 4 -m 0.
