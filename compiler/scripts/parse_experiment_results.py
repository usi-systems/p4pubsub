#!/usr/bin/env python
import os
import numpy as np
from operator import itemgetter
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("directory", type=str, help="experiment directory")
args = parser.parse_args()


def parseParams(filename):
    params = {}
    with open(filename, 'r') as f:
        for line in f:
            param, val = line.split(':', 2)
            params[param.strip()] = int(val)
    return params

def parseRepeatStats(filename):
    stats = {}
    with open(filename, 'r') as f:
        for line in f:
            if line.strip() == "": continue
            if line[0] in ['[', '\t']: continue
            param, val = line.split(':', 2)
            stats[param.strip()] = float(val)
    return stats

def parseAllRepeats(instance_dir):
    stats_files = [d for d in os.listdir(instance_dir) if d.startswith('stats_') and d.endswith('.txt')]
    all_stats = [parseRepeatStats(os.path.join(instance_dir, f)) for f in stats_files]
    return all_stats

done_dir = os.path.join(args.directory, "done")
instances = os.listdir(done_dir)

out = []

for instance in instances:
    instance_dir = os.path.join(done_dir, instance)
    params_file = os.path.join(instance_dir, "parameters.txt")
    params = parseParams(params_file)
    all_stats = parseAllRepeats(instance_dir)
    total_entries = [st['total_entries'] for st in all_stats]
    paths = [st['paths'] for st in all_stats]
    terminal_states = [st['terminal_states'] for st in all_stats]
    res = dict(params)
    res.update(dict(
        n=len(all_stats),
        terminal_states=np.mean(terminal_states),
        mean_entries=np.mean(total_entries),
        std_entries=np.std(total_entries),
        min_entries=np.min(total_entries),
        max_entries=np.max(total_entries),
        mean_paths=np.mean(paths),
        std_paths=np.std(paths),
        ))
    out.append(res)

fields = ['num_vars', 'disj_size', 'conj_size', 'num_queries']

detected_fields = out[0].keys()
fields += [f for f in detected_fields if f not in fields]

out.sort(key=itemgetter(*fields))

print '\t'.join(fields)
for o in out:
    print '\t'.join(map(str, [o[f] for f in fields]))

