#!/bin/bash
for n in 10 20 40 100 200 400 800 1000 2000 4000 10000
do
    pretty_num=$(printf "%06d" $n)
    head -n $n rules_greater_uniq200_100000.txt > rules_greater_uniq200_"$pretty_num".txt
done
