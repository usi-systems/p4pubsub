#!/bin/bash

./scripts/parse_experiment_results.py range2 | q -H -O -t  'SELECT num_vars, disj_size, conj_size, num_queries, mean_entries*3 AS bdd_space, std_entries*3 AS bdd_space_err, mean_paths*num_vars AS naive_space, std_paths*num_vars AS naive_space_err, n FROM - ORDER by num_vars, disj_size, conj_size, num_queries' > out.tsv
#~/s/plot_all_variables.py --skip-single -l n -e _err -i num_vars,disj_size,conj_size,num_queries -I num_queries,conj_size,disj_size -d bdd_space,naive_space -o plots3 out.tsv
q -tOTH 'SELECT "bdd" as LABEL, num_queries, bdd_space AS space, bdd_space_err As err FROM out.tsv WHERE conj_size=8 UNION SELECT "naive" as LABEL, num_queries, naive_space, naive_space_err FROM out.tsv WHERE conj_size=8' > num_queries_vs_space_8conj_size_1disj_size_8num_vars.tsv
q -tOTH 'SELECT "bdd" as LABEL, conj_size, bdd_space AS space, bdd_space_err As err FROM out.tsv WHERE num_queries=32 UNION SELECT "naive" as LABEL, conj_size, naive_space, naive_space_err FROM out.tsv WHERE num_queries=32' > conj_size_vs_space_32num_queries_1disj_size_8num_vars.tsv
~/s/plot_lines.py -f pdf -c ~/p4pubsub-docs/nsdi19/figures/plot.config -L naive,bdd --legend --title "Memory Usage for BDD vs Naive" --xlabel "# of subscriptions" --ylabel "Total table size" --show num_queries_vs_space_8conj_size_1disj_size_8num_vars.tsv
~/s/plot_lines.py -f pdf -c ~/p4pubsub-docs/nsdi19/figures/plot.config -L naive,bdd --legend --title "Memory Usage for BDD vs Naive" --xlabel "# of predicates" --ylabel "Total table size" --show conj_size_vs_space_32num_queries_1disj_size_8num_vars.tsv
