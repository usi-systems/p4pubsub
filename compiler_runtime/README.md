# Compiler Time Experiment

Generate 100K filters:

    python generate_itch_filters.py 100000 > rules_greater_uniq200_100000.txt

Generate files for 10, 20, etc. filters:

    ./make_many_filters.sh

Run the compiler on all of them:

    mkdir results
    for i in $(seq 20); do time ./run_exp.sh; mv stderr.log results/stderr_$(_ts).tsv; done

Parse the results:

    ./parse_results.py results/* > compile_time_nasdaq.tsv

Plot the results:

    ./parse_results.py results/*.tsv | \
        q -tOTH "SELECT * FROM - WHERE LABEL='runtime'" | \
        ~/s/plot_lines.py --show \
            --title "Compile time for ITCH workloads" - \
            --ylabel "Compile time (s)" \
            --xlabel "Number of subscriptions"


    ./parse_results.py results/*.tsv | \
        q -tOTH "SELECT * FROM - WHERE LABEL='perquery'" | \
        ~/s/plot_lines.py --show \
            --title "Compile time for ITCH workloads" - \
            --ylabel "Compile time per query (s)" \
            --xlabel "Number of subscriptions"
