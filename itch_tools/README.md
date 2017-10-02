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
headers.

    ./mold_feed.py -m 1 -M 4 -D zipf -c 100 -s AAPL,MSFT,BFN -S zipf

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

# Extract a single message type
Save the first message with MessageType `D`:

    ./replay -t D -c 1 -O D.bin ~/Downloads/08302017.NASDAQ_ITCH50
