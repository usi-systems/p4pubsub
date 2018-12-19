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

    ../camus-compiler/camus.exe -rules int-rules.txt -rt-out out/int int-spec.p4
    ../camus-compiler/camus.exe -rules itch-rules.txt -rt-out out/itch itch-spec.p4

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

## Testing

First, set up the interface on the server:

    sudo ifconfig $IFACE up 10.0.0.98
    sudo arp -s 10.0.0.1  00:11:22:33:44:01
    sudo arp -s 10.0.0.2  00:11:22:33:44:02

Check that it forwards L2 correctly:

    ping -c 1 10.0.0.1

Verify that it's sent out port 53:

    bf-sde.pm> show -p 10/1
    -----+----+---+----+------+----+---+---+---+----------------+----------------+-
    PORT |MAC |D_P|P/PT|SPEED |FEC |RDY|ADM|OPR|FRAMES RX       |FRAMES TX       |E
    -----+----+---+----+------+----+---+---+---+----------------+----------------+-
    10/1 |14/1| 53|1/53| 25G  |NONE|YES|ENB|UP |               0|               1|

Check that it forwards IPv4 correctly:

    ping -c 1 10.0.0.2

This packet should be TX from port 54:

    bf-sde.pm> show -p 10/2
    -----+----+---+----+------+----+---+---+---+----------------+----------------+-
    PORT |MAC |D_P|P/PT|SPEED |FEC |RDY|ADM|OPR|FRAMES RX       |FRAMES TX       |E
    -----+----+---+----+------+----+---+---+---+----------------+----------------+-
    10/2 |14/2| 54|1/54| 25G  |NONE|YES|ENB|UP |               0|               1|

Send an INT packet that should match the filter and be forwarded out port 52:

    ~/p4pubsub/int/tools$ ./int-sender -c 1 -n 1 10.0.0.1 1337

Generate and send an ITCH packet that should also be forwarded out port 52:

    ./mold_feed.py -m 1 -M 1 -c 1 -f Price=301,Shares=1 | ./send_mold_messages -v 3 -r - 10.0.0.1:1234
