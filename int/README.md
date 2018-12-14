# INT Filtering with Camus

We use the Camus compiler to generate a P4 program and table entries for
filtering INT packets. `spec.p4` contains the Camus specification, indicating
the header fileds to be used for filtering. `rules.txt` contains some example
filtering rules.

To generate the P4 program and table entries, run:
    
    ../camus-compiler/camus.exe -rules rules.txt -prog-out out.p4 -rt-out int spec.p4

This generates the following files:

- `out.p4`: the Camus P4 pipeline, in P4-16. Because we are using P4-14
  on the switch, I have manually translated this program to P4-14 and saved it
  as `route-tofino/programs/introuter/introuter.p4`.

- `int_mcast_groups.txt`: multicast groups to be setup on the switch.

- `int_commands.txt`: table entries formatted as simple switch CLI commands.

- `int_entries.json`: the same table entries as `int_commands.txt`, but
  formatted as JSON. This is loaded by the program that configures the switch
  at runtime: `route-tofino/ptf-tests/introuter/test.py`.

