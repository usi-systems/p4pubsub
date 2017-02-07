# Simple Router
A simple example of a P4 v16 router.

## Running

Compile and start the switch by running:

    ./run_demo.sh

This will invoke the P4c BM2 compiler, generating the `simple_router.json` file, which is run on the switch. Then, the script will start the switch and connect two hosts. You will see the mininet CLI.

The switch will have empty tables, so populate them by running (in another terminal):

    ./add_entries.sh

You should now be able to ping hosts in the mininet CLI:

    *** Starting CLI:
    mininet> h1 ping -c1 h2
    PING 10.0.1.10 (10.0.1.10) 56(84) bytes of data.
    64 bytes from 10.0.1.10: icmp_seq=1 ttl=63 time=1.29 ms
    
    --- 10.0.1.10 ping statistics ---
    1 packets transmitted, 1 received, 0% packet loss, time 0ms
    rtt min/avg/max/mdev = 1.299/1.299/1.299/0.000 ms
    mininet> 
