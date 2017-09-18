# ITCH Add Order Pub/Sub

## Setup

Build the clients, along with tools:

    make


## Latency Experiment

Run with and without filtering:

    P4APP_LOGDIR=out P4APP_IMAGE=p4lang/p4app_tofino ~/src/p4app-private/p4app run . --manifest p4app_filtering.json
    P4APP_LOGDIR=out P4APP_IMAGE=p4lang/p4app_tofino ~/src/p4app-private/p4app run . --manifest p4app_baseline.json


### Log Parsing

Get the timestamp vs. latency for each packet:

    ./parse_log out/ts.bin | q -t -T "SELECT c1,c2 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering.tsv

Just get the latency for each packet:

    ./parse_log out/ts.bin | q -t -T "SELECT c1 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering.tsv


### Plotting

Plot the CDF for both baseline and filtering on the same graph:

    ./cdf2.py baseline.tsv filtering.tsv baseline filtering
