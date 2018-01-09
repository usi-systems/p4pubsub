#!/bin/bash

BASEDIR=$(dirname "$0")

if [ $# -lt 1 ]; then
    echo "Usage: $0 EXPERIMENTS_DIR"
    exit 1
else
    EXPERIMENTS_DIR=$1
fi

DONE_DIR="$EXPERIMENTS_DIR/done"
TORUN_DIR="$EXPERIMENTS_DIR/torun"
mkdir -p $DONE_DIR
mkdir -p $TORUN_DIR

num_queries=1
disj_size=1
for num_vars in 8 #13 14 15 16 17 18 #$(seq 2 10)
do
    for conj_size in 2 3 4 5 6 7 8 
    do
        for num_queries in 32
        do
            exp_name="$num_vars"num_vars_"$num_queries"num_queries_"$disj_size"disj_size_"$conj_size"conj_size
            exp_dir=$TORUN_DIR/$exp_name
            mkdir $exp_dir

            echo "num_vars: $num_vars" >> $exp_dir/parameters.txt
            echo "conj_size: $conj_size" >> $exp_dir/parameters.txt
            echo "disj_size: $disj_size" >> $exp_dir/parameters.txt
            echo "num_queries: $num_queries" >> $exp_dir/parameters.txt

            echo "#!/bin/bash" > $exp_dir/run.sh
            echo "\$BASEDIR/iterate.sh 100 $num_vars $num_queries $disj_size $conj_size " >> $exp_dir/run.sh
            chmod +x $exp_dir/run.sh
        done
    done
done
