#!/usr/bin/env python

import sys
import struct
import argparse
from itch_message import AddOrderMessage, MoldPacket, fmtStock
from probability_distributions import Distribution, Uniform, Zipf

class DummyDist:
    def __init__(self, val):
        self.val = val
    def pick_element(self):
        return self.val

class OrderedDist:
    """ Deterministic distribution: elements are returned in order """
    def __init__(self, vals):
        self.vals = vals
        self.idx = -1

    def pick_element(self):
        self.idx = (self.idx + 1) % len(self.vals)
        return self.vals[self.idx]

def generate_message(fields=dict(), stock_dist=None):
    fields = dict(fields) # don't overwrite original fields dict
    if stock_dist is not None:
        fields['Stock'] = stock_dist.pick_element()
    return AddOrderMessage(**fields)

def generate_packet(seq, msg_cnt_dst, stock_dist=None, fields=dict()):
    msg_cnt = msg_cnt_dst.pick_element()
    messages = [generate_message(stock_dist=stock_dist, fields=fields) for _ in xrange(msg_cnt)]
    return MoldPacket(Session=1, SequenceNumber=seq, MessagePayloads=messages)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a stream of MoldUDP-encapsulated ITCH messages')
    parser.add_argument('filename', nargs='?', help='Path to output file, or "-" for STDOUT',
            type=str, default='-')
    parser.add_argument('--fields', '-f', help='Field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    parser.add_argument('--count', '-c', help='Number of packets to generate',
            type=int, default=2)
    parser.add_argument('--min-msgs', '-m', help='Minimum number of ITCH messages per packet',
            type=int, default=1)
    parser.add_argument('--max-msgs', '-M', help='Maximum number of ITCH messages per packet',
            type=int, default=None)
    parser.add_argument('--msg-dist', '-D', help='Distribution of messages per packet',
            type=str, choices=['uniform', 'zipf', 'ordered'], default='ordered')
    parser.add_argument('--stocks', '-s', help='Stock symbols to put in messages',
            type=lambda s: map(fmtStock, s.split(',')), default=None)
    parser.add_argument('--stock-dist', '-S', help='Distribution of stock symbols',
            type=str, choices=['uniform', 'zipf', 'ordered'], default='ordered')
    args = parser.parse_args()


    if args.max_msgs is None:
        args.max_msgs = args.min_msgs

    if args.min_msgs == args.max_msgs:
        msg_cnt_dst = DummyDist(args.min_msgs)
    elif args.msg_dist == 'zipf':
        msg_cnt_dst = Zipf(values=range(args.min_msgs, args.max_msgs+1))
    elif args.msg_dist == 'ordered':
        msg_cnt_dst = OrderedDist(range(args.min_msgs, args.max_msgs+1))
    else:
        msg_cnt_dst = Uniform(args.min_msgs, args.max_msgs)


    stock_dist = None
    if args.stocks:
        if args.stock_dist == 'zipf':
            stock_dist = Zipf(values=args.stocks)
        elif args.stock_dist == 'ordered':
            stock_dist = OrderedDist(args.stocks)
        else:
            stock_dist = Distribution(dict((s, 1) for s in args.stocks))


    with (sys.stdout if args.filename == '-' else open(args.filename, 'wb')) as fd:
        seq = 0
        while seq != args.count:
            seq += 1
            pkt = generate_packet(seq, msg_cnt_dst, stock_dist, args.fields)
            fd.write(pkt)

