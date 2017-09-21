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

    ./parse_log out/ts.bin | q -t -T "SELECT c1,c2 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering_timeseries.tsv

Just get the latency for each packet:

    cat filtering_timeseries.tsv | q -t -T "SELECT c1 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering_lats.tsv

Find the packet inter-arrival times:

    ./scripts/calc_deltas.py filtering_timeseries.tsv | q -t -T "SELECT * FROM - WHERE c1 < 100000" > filtering_deltas.tsv

Find the latency of the BMV2 pipeline:

    ./scripts/bmv_pipeline_latency.py out/p4s.s1.log


### Plotting

Plot the CDF for both baseline and filtering on the same graph:

    ./parse_log out/ts.bin | q -t -T "SELECT c2 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering_lats.tsv
    ./parse_log out/ts.bin | q -t -T "SELECT c2 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > baseline_lats.tsv
    ../plot_scripts/cdf2.py baseline_lats.tsv filtering_lats.tsv baseline filtering

## Parsing ITCH dumps

Print the number of messages by type:

    ./replay -a stats ~/Downloads/08302017.NASDAQ_ITCH50

Find the most popular symbols:

    ./replay -a print_symbols ~/Downloads/08302017.NASDAQ_ITCH50 | awk ' { tot[$0]++ } END { for (i in tot) print tot[i],i } ' | sort -rh | awk '{print $2"\t"$1 }' > symbols.tsv
