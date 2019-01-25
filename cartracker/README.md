# IoT Application: Tracking Cars

This experiment demonstrates detecting speeding cars using packet subscriptions.

## Compiling Rules

Compile the rules for ITCH, INT and DNS:

    mkdir out/
    ../camus-compiler/camus.exe -rules car-rules.txt -rt-out out/car car-spec.p4

The generated `*_entries.json` files should be placed in
`cartracker-tofino/ptf-tests/cartracker/`.

## Compiling and Running the P4 Program

Enter the SDE directory and use `p4_build.sh`:

    bf-sde-8.4.0$ ./p4_build.sh ~/p4pubsub/cartracker/cartracker-tofino/programs/cartracker/cartracker.p4

Once it compiles, start the switch:

    bf-sde-8.4.0$ ./run_switchd.sh -p cartracker


## Configuring the Switch

The PTF test that configures the switch will load the `*_entries.json` files
and populate the tables in the Camus pipeline. To configure the other switch
functions, edit `cartracker-tofino/ptf-tests/cartracker/test.py`.

When the PTF script is ready, run it:

    sudo -E ./run_p4_tests.sh -t ~/p4pubsub/cartracker/cartracker-tofino/ptf-tests/cartracker --target hw -s test.HW

