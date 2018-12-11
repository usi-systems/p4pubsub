# ITCH Filtering Experiment

## Setup DPDK and NICs

Extract the dpdk source dir, set the ENV, and run `dpdk-setup.sh`:

    cd ~/itch/dpdk-17.11
    cat env.sh 
    export RTE_TARGET=build
    export RTE_SDK=$HOME/itch/dpdk-17.11
    source env.sh
    sudo ~/itch/dpdk-17.11/usertools/dpdk-setup.sh

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

    cd p4pubsub/itch_tools/dpdk_sender
    vim main.c

Then, build the tool:

    make

## Experiments

### Nasdaq, 1B pkts, 1 msg/pkt, 8.25 mpps

    ~/itch/p4pubsub/itch_tools/generate_mold_messages -o a -c 0 -m 1 -r  ~/itch/08302017.NASDAQ_ITCH50 > 08302017.NASDAQ_ITCH50_ao_1m.bin
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/08302017.NASDAQ_ITCH50_ao_1m.bin -c 1000000000 -r 8250000 -l filtered.bin -P 1234
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/08302017.NASDAQ_ITCH50_ao_1m.bin -c 1000000000 -r 8250000 -l unfiltered.bin -P 1235

### 5% GOOGL, 1-12 msg/ptk (zipf), 500M pkts, 6.56 mpps

    ~/itch/p4pubsub/itch_tools/mold_feed.py -c 10000000 -m 1 -M 12 -D zipf -s GOOGL,______ -S 0.05,0.95 > ~/itch/1-12zipm_0.05GOOGL_10M.bin
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/1-12zipm_0.05GOOGL_10M.bin -c 1000000000 -r 6560000 -l filtered.bin -P 1234
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/1-12zipm_0.05GOOGL_10M.bin -c 1000000000 -r 6560000 -l unfiltered.bin -P 1235

### 100% GOOGL, 12 msg/ptk, 500M pkts, 2 mpps

    ITCH_STOCK="GOOGL   " ~/itch/p4pubsub/itch_tools/generate_mold_messages -o a -c 10000 -m 12 -M 12 -p 1 > ~/itch/12m_1GOOGL_10K.bin
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/12m_1GOOGL_10K.bin -c 50000000 -r 2000000 -l filtered.bin -P 1234
    time sudo ITCH_STOCK="GOOGL   " ./build/main -l 0,8 -n 4 -w 02:00.1 -w 81:00.1 -- -f ~/itch/12m_1GOOGL_10K.bin -c 50000000 -r 2000000 -l unfiltered.bin -P 1235

## Plotting Graphs

    make -f cdf_Makefile -j4
