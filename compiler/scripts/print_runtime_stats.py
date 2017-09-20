#!/usr/bin/env python
import numpy as np
import sys

filename = sys.argv[1]

int_size = 16
half_range_size = (int_size / 4) - 1
full_range_size = (int_size / 2) - 1

tables = {}
total_entries = 0
total_miss_entries = 0

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        if not line.startswith("table_add tbl_"): continue

        total_entries += 1
        is_miss, is_range, is_exact = False, False, False

        full_tbl_name = line.split(' ', 2)[1]
        if full_tbl_name.endswith('_miss'):
            is_miss = True
            tbl_name = full_tbl_name.rstrip('_miss')
        elif full_tbl_name.endswith('_exact'):
            is_exact = True
            tbl_name = full_tbl_name[:-6]
        elif full_tbl_name.endswith('_range'):
            is_range = True
            tbl_name = full_tbl_name[:-6]

        if tbl_name not in tables:
            tables[tbl_name] = dict(exact=0, half_range=0, full_range=0, miss=0)

        if is_miss:
            total_miss_entries += 1
            tables[tbl_name]['miss'] += 1
        elif is_exact:
            tables[tbl_name]['exact'] += 1
        elif '->' in line:
            tables[tbl_name]['full_range'] += 1
        else:
            tables[tbl_name]['half_range'] += 1

for tbl_name in tables:
    print "[%s]" % tbl_name
    print "\texact:\t\t", tables[tbl_name]['exact']
    print "\thalf_range:\t", tables[tbl_name]['half_range']
    print "\tfull_range:\t", tables[tbl_name]['full_range']
    tcam_entries = half_range_size * tables[tbl_name]['half_range']
    tcam_entries += full_range_size * tables[tbl_name]['full_range']
    print "\ttcam_entries:\t", tcam_entries
    print


print "tables:\t\t\t", len(tables)
print "total_miss_entries:\t", total_miss_entries
print "total_entries:\t\t", total_entries

