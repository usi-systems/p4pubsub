require 'yaml'

module CamusPostProcessing 
	def p4pp file_name
		text = File.read(file_name)
		new_contents = text.gsub(/ig_intr_md_for_tm/, "standard_metadata")
		new_contents.gsub!("ucast_egress_port", "egress_spec")
		new_contents.gsub!("mcast_grp_a", "egress_spec")
		new_contents.each_line do |line|
			new_contents.gsub!(line, "") if line.include? "tofino"
		end
		File.open(file_name, "w") {|file| file.puts new_contents }
	end
end


include CamusPostProcessing

module Config
	@@CONFIG_FILE_NAME = "config.yaml"
	@@CONFIGS = {}

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

	def p4_compile p4_file, output_file
		input = "#{@@CONFIGS["base_directory"]}#{p4_file}"
		output = "#{@@CONFIGS["output_directory"]}"
		output_file = "#{output_directory}#{output_file}"
		command = "#{@@CONFIGS["p4_compiler"] }"
	end
end

include Config

rules_file 		= "#{Config.g "base_directory"}examples/itch_rules.txt" 
base_name 		= "ruby_g_"
p4_output 		= "#{Config.g "output_directory"}ruby_g_.p4"
input_template 	= "#{Config.g "base_directory"}examples/itch.p4"

Config.execute_camus rules_file, base_name, p4_output, input_template



