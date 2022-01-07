ruby make_experiments.rb -src . -datasets ../datasets/ -f
find ./out/ -name "run_exp.sh" -printf 'cd %h; ./run_exp.sh; \0' | xargs -L1 -0 -P40 bash -c
