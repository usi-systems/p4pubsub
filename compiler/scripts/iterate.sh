#!/bin/bash

iterations=$1
shift

for i in $(seq $iterations)
do
    $BASEDIR/ssbg_camus2.py --zipf --attr-space-size $1 --filters $2 --disj-size $3 --conj-size $4 > queries_"$i".txt
    $BASEDIR/main.native queries_"$i".txt > tables_"$i".dot
    $BASEDIR/print_runtime_stats.py tables_"$i".dot > stats_"$i".txt
    rm tables_"$i".dot
done
