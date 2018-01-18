# SYN Flood Experiment

## Running the experiment

- Setup the net namespaces with ARP tables, modifying the script for each machine:

    ./netns_ens1f1.sh

- Start lighttpd on the server:

    sudo ip netns exec ns_ens1f1 lighttpd -D -f lighttpd.conf

- Start capturing traffic on the server:

    sudo ip netns exec ns_ens1f1 tcpdump -s 60 -i ens1f1 -w out.pcap "tcp port 80"

- On the client machine, start the experiment:

    sudo ip netns exec ns_ens1f1 ./run_syn_experiment.sh

## Processing the packet capture

This should be done for both the baseline and mitigation modes.

- Create a timeseries from `out.pcap`, using 1000us bins:

     tcpdump -r out.pcap -ttttt  | ~/s/tcpdump_timestamps.py | ~/s/bin.py 1000 - > baseline_series.tsv

- Smooth the timeseries, shift the window (starting at 4300ms and lasting 600ms), and adjust the y-axis units:

    ~/s/smooth.py 50 baseline_series.tsv | ~/s/shift.py -4300 - | ~/s/filter.py 0 600 - | ~/s/mul_y.py 1000 - > baseline_smooth.tsv

## Plotting the timeseries

Plot both experiments on the same axis:

     ~/s/plot_xy.py baseline_smooth.tsv mitigated_smooth.tsv
