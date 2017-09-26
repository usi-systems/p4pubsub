#!/usr/bin/env python

import sys
import argparse
from itch_message import AddOrderMessage

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a dump of ITCH messages')
    parser.add_argument('filename', nargs='?', help='Path to output file. If unspecified, defaults to STDOUT',
            type=str, default='-')
    parser.add_argument('--fields', '-f', help='Field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    args = parser.parse_args()

    with (sys.stdout if args.filename == '-' else open(args.filename, 'wb')) as fd:
        fd.write(AddOrderMessage(**args.fields))
