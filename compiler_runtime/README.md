# Compiler Time Experiment

Generate 100K filters:

    python generate_itch_filters.py 100000 > rules_greater_uniq200_100000.txt

Generate files for 10, 20, etc. filters:

    ./make_many_filters.sh

Run the compiler on all of them:

    mkdir results
    for i in $(seq 20); do time ./run_exp.sh; mv stderr.log results/stderr_$(_ts).tsv; done

Parse the results:

    ./parse_results.py results/* > compile_time.tsv

Plot the results:

    ~/s/plot_lines.py --show \
        --labels runtime \
        --title "Compile time for ITCH workloads" \
        --ylabel "Compile time (s)" \
        --xlabel "Number of subscriptions" \
        compile_time.tsv
    mv compile_time.png compile_time_total.png

    ~/s/plot_lines.py --show \
        --labels perquery \
        --title "Compile time for ITCH workloads" \
        --ylabel "Compile time per query (s)" \
        --xlabel "Number of subscriptions" \
        compile_time.tsv
    mv compile_time.png compile_time_perquery.png
