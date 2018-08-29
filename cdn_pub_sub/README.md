# Publish-subscribe over a data center network
A ruby program for generating a fat-tree based data center network for a distributed publish-subscribe scenario. The generated network config and P4 files can be simulated with BMv2 switches and Mininet.

## Before the start
To use this appliction you need to have installed below applications:
- Camus compiler
- P4 Compiler
- Integration BMv2 over Mininet

There is a `config.yaml` so as to set the file address of the compilers and also to specify some directories:

```
base_directory: # absolute address to the current address
output_directory: # directory for the generated files
camus_compiler: # address to the Camus compiler, including the input parameters
p4_compiler: # address of P4 compiler

fat_tree_bmv2_log: # enable bmv2 log 
fat_tree_pcap_dump: # enable pcap log
fat_tree_auto_control_plane: # enable auto control plane
fat_tree_cli: # enable mininet command line
```

