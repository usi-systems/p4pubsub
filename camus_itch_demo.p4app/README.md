# Filtering ITCH Messages with Camus

This demo uses Camus to generate a P4 program and data-plane that filter ITCH messages according to the rules in
`rules.txt`. 

## How to run it
1. If you haven't done so already, build the Camus compiler in `../compiler`.

2. Compile `rules.txt`. This can be done by running:

    make

3. Run it with `p4app`:

    p4app run .

In p4app's output, you can see the number of messages received by each host. For more detail on the messages they
received, look at their log files, which can be found in p4app's log directory.

## What does the compiler generate?
Camus compiles `rules.txt` to generate the `p4src/generated_router.p4` using the template in `router.p4.tmpl`. For the
data-plane rules, Camus generates `generated_commands.txt` and `generated_mcast_groups.txt`, which are automatically
loaded by p4app (see `p4app.json`).

## Adding new rules
Simply edit `rules.txt`. To see the available fields in the `add_order` header, see `p4src/header.p4`.

## Sending different ITCH messages
The `Makefile` generates `add_order.itch`, which is an ITCH message dump containing a sequence of Add Order messages.
This message dump is sent to the swich by the ITCH `replay` tool. To add or remove messages, edit the `itch_messages`
rule in the `Makefile`, and then run `make` again.
