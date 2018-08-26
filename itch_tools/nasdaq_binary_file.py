#!/usr/bin/env python

import sys
import argparse
from mold_feed import generate_message
from probability_distributions import Distribution, Uniform, Zipf, DegenerateDist, OrderedDist
from itch_message import MoldMessage, AddOrderMessage, MessageForType, MoldPacket, fmtStock


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a BinaryFILE of ITCH messages')
    parser.add_argument('filename', nargs='?', help='Path to output file, or "-" for STDOUT',
            type=str, default='-')
    parser.add_argument('--fields', '-f', help='Message field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    parser.add_argument('--count', '-c', help='Number of packets to generate',
            type=int, default=2)
    parser.add_argument('--stocks', '-s', help='Stock symbols to put in messages',
            type=lambda s: map(fmtStock, s.split(',')), default=None)
    parser.add_argument('--stock-dist', '-S', help='Distribution of stock symbols',
            type=str, default='ordered')
    parser.add_argument('--msg-types', '-t', help='MessageTypes to generate. E.g. A,L,Y',
            type=lambda s: s.split(','), default=['A'])
    parser.add_argument('--msg-types-dist', '-T', help='Distribution of MessageTypes',
            type=str, choices=['uniform', 'zipf', 'ordered'], default='ordered')
    args = parser.parse_args()



    stock_dist = None
    if args.stocks:
        if args.stock_dist == 'zipf':
            stock_dist = Zipf(values=args.stocks)
        elif args.stock_dist == 'ordered':
            stock_dist = OrderedDist(args.stocks)
        elif args.stock_dist == 'uniform':
            stock_dist = Distribution(dict((s, 1) for s in args.stocks))
        else:
            probs = map(float, args.stock_dist.split(','))
            assert sum(probs) == 1
            assert len(probs) == len(args.stocks)
            stock_dist = Distribution(dict(zip(args.stocks, probs)))

    msg_constructors = map(MessageForType, args.msg_types)
    if len(msg_constructors) == 0:
        msg_type_dist = DegenerateDist(msg_constructors[0])
    elif args.msg_types_dist == 'zipf':
        msg_type_dist = Zipf(values=msg_constructors)
    elif args.msg_types_dist == 'ordered':
        msg_type_dist = OrderedDist(msg_constructors)
    else:
        msg_type_dist = Distribution(dict((c, 1) for c in msg_constructors))


    with (sys.stdout if args.filename == '-' else open(args.filename, 'wb')) as fd:
        seq = 0
        while seq != args.count:
            seq += 1
            fields = dict()
            msg = MoldMessage(generate_message(stock_dist=stock_dist, msg_type_dist=msg_type_dist, fields=fields))
            fd.write(msg)

