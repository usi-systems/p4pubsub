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
states = set()
terminal_states_cnt = 0

trans = {}
def addTrans(q1, q2):
    if q1 not in trans:
        trans[q1] = set()
    trans[q1].add(q2)

def countPaths(q=0):
    if q not in trans: return 1
    return sum(countPaths(q2) for q2 in trans[q])


with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        if not line.startswith("table_add "): continue

        full_tbl_name = line.split(' ', 2)[1]

        total_entries += 1
        is_miss, is_range, is_exact = False, False, False

        if full_tbl_name.endswith('_miss'):
            is_miss = True
            tbl_name = full_tbl_name.rstrip('_miss')
        elif full_tbl_name.endswith('_exact'):
            is_exact = True
            tbl_name = full_tbl_name[:-6]
        elif full_tbl_name.endswith('_range'):
            is_range = True
            tbl_name = full_tbl_name[:-6]
            range_match = line.split()[4]
        elif full_tbl_name == "query_actions":
            terminal_states_cnt += 1
            continue
        else:
            continue

        state = int(line.split()[3])
        next_state = int(line.split('=>')[1].split()[0])
        states.add(next_state)
        addTrans(state, next_state)

        if tbl_name not in tables:
            tables[tbl_name] = dict(exact=0,
                    half_range=0,
                    full_range=0,
                    unique_half_ranges=set(),
                    unique_full_ranges=set(),
                    miss=0)

        if is_miss:
            total_miss_entries += 1
            tables[tbl_name]['miss'] += 1
        elif is_exact:
            tables[tbl_name]['exact'] += 1
        elif '->' in line:
            tables[tbl_name]['full_range'] += 1
            tables[tbl_name]['unique_full_ranges'].add(range_match)
        else:
            tables[tbl_name]['half_range'] += 1
            tables[tbl_name]['unique_half_ranges'].add(range_match)

for tbl_name in tables:
    unique_half_ranges = len(tables[tbl_name]['unique_half_ranges'])
    unique_full_ranges = len(tables[tbl_name]['unique_full_ranges'])
    print "[%s]" % tbl_name
    print "\texact:\t\t\t", tables[tbl_name]['exact']
    print "\thalf_range:\t\t", tables[tbl_name]['half_range']
    print "\tunique_half_range:\t", unique_half_ranges
    print "\tfull_range:\t\t", tables[tbl_name]['full_range']
    print "\tunique_full_range:\t", unique_full_ranges
    tcam_entries = half_range_size * tables[tbl_name]['half_range']
    tcam_entries += full_range_size * tables[tbl_name]['full_range']
    print "\ttcam_entries:\t\t", tcam_entries
    print "\tunique_tcam_ranges:\t", half_range_size * unique_half_ranges + full_range_size * unique_full_ranges
    print


print "paths:\t\t\t", countPaths(0)
print "states:\t\t\t", len(states)
print "terminal_states:\t\t\t", terminal_states_cnt
print "tables:\t\t\t", len(tables)
print "total_miss_entries:\t", total_miss_entries
print "total_entries:\t\t", total_entries
