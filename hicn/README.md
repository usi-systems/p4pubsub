# Camus HICN Forwarder

Compile `hicn.p4`:

    cd bf-sde-8.4.0
    ./p4_build.sh ~/p4pubsub/hicn/hicn-tofino/programs/hicn/hicn.p4

Compile the rules:
    
    ../camus-compiler/camus.exe -rules rules.txt spec.p4

Copy the entries and mcast groups into the PTF directory:

    cp spec_entries.json hicn-tofino/ptf-tests/hicn/entries.json
    cp spec_mcast_groups.txt hicn-tofino/ptf-tests/hicn/mcast.txt

Start the switch:

    bf-sde-8.4.0$ ./run_switchd.sh -p hicn

In another terminal, start the PTF as the controller:

    bf-sde-8.4.0$ sudo -E ./run_p4_tests.sh -t ~/p4pubsub/hicn/hicn-tofino/ptf-tests/hicn/ --target hw -s test.HW
