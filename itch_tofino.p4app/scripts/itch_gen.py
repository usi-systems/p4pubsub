#!/usr/bin/env python

import sys
import struct
import argparse

add_order_struct = struct.Struct("!c H H 6s Q c L 8s L")
uint64_struct = struct.Struct("!Q")
uint16_struct = struct.Struct("!H")

def fmtStock(stock):
    assert len(stock) <= 8
    return "%-8s" % stock

# I assume that this host is little-endian
def hton48(i):
    return uint64_struct.pack(i)[:6]


def AddOrderMessage(
	MessageType='A',
        StockLocate=0,
        TrackingNumber=0,
	Timestamp=0,
	OrderReferenceNumber=0,
	BuySellIndicator='S',
	Shares=0,
	Stock='EMPTY   ',
	Price=0
        ):

    StockLocate, TrackingNumber, Timestamp = int(StockLocate), int(TrackingNumber), int(Timestamp)
    OrderReferenceNumber, Shares, Price = int(OrderReferenceNumber), int(Shares), int(Price)

    data = add_order_struct.pack(MessageType, StockLocate, TrackingNumber,
            hton48(Timestamp), OrderReferenceNumber, BuySellIndicator,
            Shares, fmtStock(Stock), Price)

    assert len(data) == 36

    size_header = uint16_struct.pack(len(data))
    return size_header + data

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a dump of ITCH messages')
    parser.add_argument('filename', nargs='?', help='Path to output file, or "-" for STDOUT',
            type=str, default='-')
    parser.add_argument('--fields', '-f', help='Field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    args = parser.parse_args()

    with (sys.stdout if args.filename == '-' else open(args.filename, 'wb')) as fd:
        fd.write(AddOrderMessage(**args.fields))
