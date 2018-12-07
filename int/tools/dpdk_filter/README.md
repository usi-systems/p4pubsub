# INT Filtering Experiment

## Setup DPDK and NICs

Extract the dpdk source dir, set the ENV, and run `dpdk-setup.sh`:

    cd ~/dpdk-17.11
    cat env.sh 
    export RTE_TARGET=build
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


Edit `main.c` and change `dst_mac` to the NIC that should receive (and filter) the feed.

    cd p4pubsub/int/tools/dpdk_sender
    vim main.c

Then, build the tool:

    make

