#!/bin/bash

PROG=simple_router

source $HOME/env.sh

SWITCH_PATH=$BMV2_PATH/targets/simple_switch/simple_switch

$P4C_PATH/build/p4c-bm2-ss p4src/"$PROG".p4 -o "$PROG".json --p4-16
sudo python $BMV2_PATH/mininet/1sw_demo.py \
    --behavioral-exe $BMV2_PATH/targets/simple_switch/simple_switch \
    --json "$PROG".json
