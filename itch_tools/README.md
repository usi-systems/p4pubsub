# ITCH Tools
A collection of tools for generating, sending and receiving ITCH messages
encapsulated in MoldUDP64 packets.

## Overview of ITCH formats

# Nasdaq BinaryFILE
Nasdaq provides dumps of ITCH feeds here:
ftp://emi.nasdaq.com/ITCH/

These files are stored in the BinaryFILE file format:
https://www.nasdaqtrader.com/content/technicalSupport/specifications/dataproducts/binaryfile.pdf

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

## Setup
Build the clients, along with tools:

    make

## Generating ITCH messages
The script `./itch_message.py` generates an ITCH message in the
BinaryFILE format, compatible with the dumps provided by Nasdaq. For now, the
script only generates Add Order messages. For example, generate a BinaryFILE
with two Add Order messages:

    ./itch_message.py -f StockLocate=1,Stock=AAPL,Shares=3,BuySellIndicator=B,Price=123 > out.bin
    ./itch_message.py -f StockLocate=2,Stock=MSFT,Shares=3,BuySellIndicator=S,Price=321 >> out.bin

## Generating MoldUDP64 encapsulated ITCH messages
`./mold_feed.py` generates a stream of ITCH messages encapsulated in MoldUDP64
headers. It can generate streams with different distributions:

    ./mold_feed.py -m 1 -M 4 -D zipf -c 100 -s AAPL,MSFT,BFN -S zipf

For example, to create the following stream of messages:

    pkt 1: {AddOrder(AAPL), StockTradingAction}                    (MessageCount: 2)
    pkt 2: {AddOrder(IBM)}                                         (MessageCount: 1)
    pkt 3: {RegSHO, AddOrder(MSFT), MarketParticipatingPosition}   (MessageCount: 3)

you could construct the stream one packet at a time:

    ./mold_feed.py -c 1 -m 2 -t A,H -s AAPL > out.bin
    ./mold_feed.py -c 1 -m 1 -t A -s IBM >> out.bin
    ./mold_feed.py -c 1 -m 3 -t Y,A,L -s MSFT >> out.bin

which you can then send to the network with:

    ./send_mold_messages -v 3 -r out.bin 127.0.0.1:10001

To create a stream of add orders, specifying the probability of each stock
symbol (1% GOOGL and 99% AAPL):

    ./mold_feed.py -c 1 -m 1 -s GOOGL,AAPL -S 0.01,0.99 > out.bin


## Sending MoldUDP64 messages
The `./send_mold_messages` tool sends MoldUDP64 messages to the network.

    ./mold_feed.py -c 1 | ./send_mold_messages -v 2 127.0.0.1:10001

You can control the rate using `pv`:

    ./mold_feed.py -c 1000 -m 1 -s AAPL,MSFT | pv -L 1M | ./send_mold_messages -v2 127.0.0.1:10001

### Log Parsing
The `receiver` program can output a log of timestamps. For each message
received, the log contains the time the message was sent, along with the time
it was received. The log is stored in a binary format that can be parsed by the
`./parse_log` tool.

Get the timestamp vs. latency for each packet:

    ./parse_log out/ts.bin | q -t -T "SELECT c1,c2 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering_timeseries.tsv

Just get the latency for each packet:

    cat filtering_timeseries.tsv | q -t -T "SELECT c1 FROM - WHERE c2 < 100000 AND c3 LIKE 'ABC%'" > filtering_lats.tsv

## Parsing ITCH BinaryFILE dumps
Print the number of messages by type:

    ./replay -o t ~/Downloads/08302017.NASDAQ_ITCH50

Find the most popular symbols:

    ./replay -o s ~/Downloads/08302017.NASDAQ_ITCH50 | awk ' { tot[$0]++ } END { for (i in tot) print tot[i],i } ' | sort -rh | awk '{print $2"\t"$1 }' > symbols.tsv

Get the timestamp for Add Orders for "GOOGL":

    ./replay -o a ~/Downloads/08302017.NASDAQ_ITCH50 | grep GOOGL | cut -f4

Get the message inter-arrival times:

    ./replay -o a ~/Downloads/08302017.NASDAQ_ITCH50 | grep GOOGL | cut -f4 | ../scripts/deltas.py -

Create a timestamp/frequency timeseries with 1s bin size:

    ./replay -o a ~/Downloads/08302017.NASDAQ_ITCH50 | grep GOOGL | cut -f4 | ../scripts/bin.py 1000000000

Finding the correlation between two timeseries:

    ./replay -o a ~/Downloads/08302017.NASDAQ_ITCH50 | grep "AAPL    " | cut -f4 | ./scripts/bin.py 1000000000 - > aapl_ts.tsv
    ./replay -o a ~/Downloads/08302017.NASDAQ_ITCH50 | grep "GOOG    " | cut -f4 | ./scripts/bin.py 1000000000 - > goog_ts.tsv
    ../scripts/corr_ts.py aapl_ts.tsv goog_ts.tsv


# Extract a single message type
Save the first message with MessageType `D`:

    ./replay -t D -c 1 -O D.bin ~/Downloads/08302017.NASDAQ_ITCH50

# Sending/receiving with DPDK
Assuming that eth0 and eth1 are connected to each other, you can send and
receive from the same machine.

Start the receiver:

    cd dpdk_receiver
    make
    sudo ITCH_STOCK="AAPL    " ./build/main -l 0 -n 4 --vdev=net_pcap0,iface=eth0 -- -p 1 -l out.bin

Send 10M ITCH packets:

    cd dpdk_sender
    make
    sudo ITCH_STOCK="AAPL    " ./build/main -l 1 -n 4 --vdev=net_pcap0,iface=eth1 --no-huge --no-shconf -- -p 1 -C "(0,0,1)" -N -c 10000000

Then, stop the receiver, and parse the log to get latencies:

    ./parse_log dpdk_receiver/out.bin | cut -f2 > lats.tsv
