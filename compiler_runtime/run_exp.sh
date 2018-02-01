#!/bin/bash

P4V_PATH=$HOME/src/p4v/mutine

STDOUT_FILENAME=stdout.log
STDERR_FILENAME=stderr.log

for n in 10 20 40 100 200 400 800 1000 2000 4000 10000
do
    pretty_num=$(printf "%06d" $n)
    rules_file=rules_greater_uniq200_"$pretty_num".txt
    echo $n >> $STDERR_FILENAME
    (time $P4V_PATH/p4query.exe -rules $rules_file ./p4src/spec_router.p4) >> $STDOUT_FILENAME 2>> $STDERR_FILENAME
done
