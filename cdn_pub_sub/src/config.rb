require 'yaml'

module Config
	@@CONFIG_FILE_NAME = ""
	@@CONFIGS = {}
	@@TOPOLOGY = {}

	def g key
		load_config_file if @@CONFIGS.empty?
		@@CONFIGS[key]
	end

	def load_config_file
		@@CONFIGS = YAML.load_file(@@CONFIG_FILE_NAME)	
	end	

	def execute_camus rules_file, base_name, ouput_p4_file, itch_p4_file
		command = (g "camus_compiler") % 
			[
				rules_file, 
				itch_p4_file
			]
		p command
		system command
	end

	def load_topology topo_file_name, config_file_name
		topology_file = File.read topo_file_name
		@@CONFIG_FILE_NAME = config_file_name

		topo = JSON.parse topology_file

		raise "topology is not supported!" unless topo["target"]["topology"].start_with? "fat-tree" # for now, only the 

		@@TOPOLOGY = FatTreeLocal.new(topo) if(topo["target"]["topology"].eql? "fat-tree-local")
		@@TOPOLOGY = FatTreeGlobal.new(topo) if(topo["target"]["topology"].eql? "fat-tree-global")
	end
end
