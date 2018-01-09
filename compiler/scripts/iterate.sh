#!/bin/bash

iterations=$1
shift

for i in $(seq $iterations)
do
    $BASEDIR/ssbg_camus.py --zipf --attr-space-size $1 --filters $2 --disj-size $3 --conj-size $4 > queries_"$i".txt
    $BASEDIR/../main.native -o . queries_"$i".txt > /dev/null
    $BASEDIR/print_runtime_stats.py generated_commands.txt > stats_"$i".txt
done
