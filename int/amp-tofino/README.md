# Testing with the SDE

- Download and install SDE 8.4.0
- Compile the program:

    ./p4_build.sh ~/p4pubsub/int/amp-tofino/programs/intamp/intamp.p4

- In the first shell, start the model:

    ./run_tofino_model.sh -p intamp

- In the second shell, start switchd:

    ./run_switchd.sh -p intamp

- In the third shell, run the tests:

     sudo -E ./run_p4_tests.sh -t ~/p4pubsub/int/amp-tofino/ptf-tests/intamp --target asic-model -s test

