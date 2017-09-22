# ITCH Add Order Pub/Sub

## Overview of ITCH formats

# ITCH dump files

Nasdaq provides dumps of ITCH feeds here:
ftp://emi.nasdaq.com/ITCH/

These files are a sequence of messages in a binary format. Before each message,
there is a 2 byte *network endian* field with the size of the message. The
message data is the actual ITCH message (i.e. the first byte of the message
data payload is the ITCH `MessageType` field)

    
    offset in file
                    +----------------+
           0        |  Message Size  |
                    +----------------+
           2        |                |
                    |  Message Data  |
                    |                |
                    +----------------+
                    |  Message Size  |
                    +----------------+
                    |                |
                    |  Message Data  |
                    |                |
                    |      ...       |


## Generating ITCH messages

The script `scripts/itch_gen.py` generates an ITCH message dump file compatible
with those provided by Nasdaq. For now, it only generates Add Order messages.
For example, generate an ITCH dump file with two Add Order messages:

    ./scripts/itch_gen.py -f StockLocate=1,Stock=AAPL,Shares=3,BuySellIndicator=B,Price=123 > out.itch
    ./scripts/itch_gen.py -f StockLocate=2,Stock=MSFT,Shares=3,BuySellIndicator=S,Price=321 >> out.itch

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
