# Coexistence and Generality Experiment

This experiment demonstrates running multiple packet subscription pipelines in
addition to basic switch functions.

We used Camus to compile a pipeline for:
 - INT filtering
 - ITCH filtering

If the packet contains an application header, it executes the corresponding
Camus pipeline. Otherwise, it executes some basic switch tables:
 - `dmac` forwarding
 - `ipv4_lpm`

## Compiling Rules

Compile the rules for both ITCH and INT:

The generated `*_entries.json` files should be placed in
`coexistence-tofino/ptf-tests/coexistence/`.

## Compiling and Running the P4 Program

Enter the SDE directory and use `p4_build.sh`:

    bf-sde-8.4.0$ ./p4_build.sh ~/p4pubsub/coexistence/coexistence-tofino/programs/coexistence/coexistence.p4

Once it compiles, start the switch:

    bf-sde-8.4.0$ ./run_switchd.sh -p coexistence


## Configuring the Switch

The PTF test that configures the switch will load the `*_entries.json` files
and populate the tables in the Camus pipelines. To configure the other switch
functions, edit `coexistence-tofino/ptf-tests/coexistence/test.py`.

When the PTF script is ready, run it:

    sudo -E ./run_p4_tests.sh -t ~/p4pubsub/coexistence/coexistence-tofino/ptf-tests/coexistence --target hw -s test.HW
