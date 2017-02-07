#!/bin/bash

PROG=simple_router

source $HOME/env.sh

CLI_PATH=$BMV2_PATH/targets/simple_switch/sswitch_CLI

$CLI_PATH "$PROG".json < commands.txt
