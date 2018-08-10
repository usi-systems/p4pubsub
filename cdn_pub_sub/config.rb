require 'yaml'

module Config
	@@CONFIG_FILE_NAME = "config.yaml"
	@@CONFIGS = {}
	@@TOPOLOGY = {}

	def g key
		load_config_file if @@CONFIGS.empty?
		@@CONFIGS[key]
	end

	def load_config_file
		@@CONFIGS = YAML.load_file(@@CONFIG_FILE_NAME)	
	end	

	def execute_camus rules_file, base_name, ouput_p4_file, input_template
		command = (g "camus_compiler") % 
			[
				rules_file, 
				base_name,
				ouput_p4_file,
				input_template
			]
		p command
		system command
		CamusPostProcessing.p4pp ouput_p4_file
	end

	def load_topology file_name
		topology_file = File.read file_name
		topo = JSON.parse topology_file

		raise "topology is not supported!" unless topo["target"]["topology"].eql? "fat-tree" # for now, only the 
		@@TOPOLOGY = FatTree.new topo
	end
end
