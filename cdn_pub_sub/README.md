# Publish-subscribe over a data center network
A ruby program for generating a fat-tree based data center network for a distributed publish-subscribe scenario. The generated network config and P4 files can be simulated with BMv2 switches and Mininet.

## Before the start
To use this appliction you need to have installed below applications:
- Camus compiler
- P4 Compiler
- Integration BMv2 over Mininet

There is a `config.yaml` so as to set the file address of the compilers and also to specify some directories:

```yaml
base_directory: # absolute address to the current address
output_directory: # directory for the generated files
camus_compiler: # address to the Camus compiler, including the input parameters and the P4 template!
p4_compiler: # address of P4 compiler

fat_tree_bmv2_log: # enable bmv2 log 
fat_tree_pcap_dump: # enable pcap log
fat_tree_auto_control_plane: # enable auto control plane
fat_tree_cli: # enable mininet command line
```

## Topology file
A file in which it is possible to describe the topology of the network and the queries of each host/subscriber within the network. In this file, `pod_size` stands for the number of pods in the network. All host names are formed from three numbers, `pod`, `ToR` and `host` indeces:
- `pod` index: indicates the pod ID, that host belongs to.
- `ToR` index: indicates the ToR (top of rack) switch, that host is connected to.
- `host` index: indicates the ID of the host. 

```json
{
	"version" : "0.0.1",
	"target" : {
		"topology": "fat-tree",
		"pod_size" : 4
	},
	"hosts": {
		"h_1_4_1": {
			"queries" : "examples/queries/q11.txt"
		},
		"h_1_4_2": {
			"queries" : "examples/queries/q12.txt"
		},
		"h_1_3_1": {
			"queries" : "examples/queries/q13.txt"
		},
		"h_1_3_2": {
			"queries" : "examples/queries/q14.txt"
		},


		"h_2_4_1": {
			"queries" : "examples/queries/q21.txt"
		},
		"h_2_4_2": {
			"queries" : "examples/queries/q22.txt"
		},
		"h_2_3_1": {
			"queries" : "examples/queries/q23.txt"
		},
		"h_2_3_2": {
			"queries" : "examples/queries/q24.txt"
		},


		"h_3_4_1": {
			"queries" : "examples/queries/q31.txt"
		},
		"h_3_4_2": {
			"queries" : "examples/queries/q32.txt"
		},
		"h_3_3_1": {
			"queries" : "examples/queries/q33.txt"
		},
		"h_3_3_2": {
			"queries" : "examples/queries/q34.txt"
		},


		"h_4_4_1": {
			"queries" : "examples/queries/q41.txt"
		},
		"h_4_4_2": {
			"queries" : "examples/queries/q42.txt"
		},
		"h_4_3_1": {
			"queries" : "examples/queries/q43.txt"
		},
		"h_4_3_2": {
			"queries" : "examples/queries/q44.txt"
		}
	}
}
```

# Running

You can simply run the `main.rb`, given the topology file as an input arguments, to create the corresponding Mininet config files. 

```bash
ruby main.rb examples/cdn_topo.json
```
Now, it is possible to use the generated files in `generated` folder to run a Mininet simulation:

```bash
p4c-bm2-ss --p4v 14 ruby_g.p4 -o gen.json
sudo python  ~/cdn_pub_sub/bmv2_mininet/multi_switch_mininet.py --log-dir "/tmp/mininet" --manifest ./p4app.json --target "multiswitch" --auto-control-plane --behavioral-exe ~/behavioral-model/targets/simple_switch/simple_switch --json ./gen.json
```

