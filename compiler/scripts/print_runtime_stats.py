#!/usr/bin/env python
import numpy as np
import sys

filename = sys.argv[1]

tables = {}
miss_tables = {}

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        if not line.startswith("table_add tbl_"): continue

        full_tbl_name = line.split(' ', 2)[1]

        if full_tbl_name.endswith('_miss'):
            tbl_name = full_tbl_name.lstrip('_miss')
            if tbl_name not in miss_tables: miss_tables[tbl_name] = 0
            miss_tables[tbl_name] += 1
        else:
            if full_tbl_name not in tables: tables[full_tbl_name] = 0
            tables[full_tbl_name] += 1

print "tables:\t\t\t", len(tables)
print "match_entries_sum:\t", sum(tables.values())
print "match_entries_mean:\t", np.mean(tables.values())
print "match_entries_std:\t", np.std(tables.values())
print "miss_entries_sum:\t", sum(miss_tables.values())
print "miss_entries_mean:\t", np.mean(miss_tables.values())
print "miss_entries_std:\t", np.std(miss_tables.values())
print "total_entries:\t\t", sum(tables.values()) + sum(miss_tables.values())
