#!/bin/bash
for n in $(seq 10 10 1000) 10000
do
    pretty_num=$(printf "%06d" $n)
    head -n $n rules_greater_uniq200_100000.txt > rules_greater_uniq200_"$pretty_num".txt
done
