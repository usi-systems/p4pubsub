require 'json'
require_relative 'fat_tree'
require_relative 'config'

module CamusPostProcessing 
	def p4pp file_name
		text = File.read(file_name)
		new_contents = text.gsub("ig_intr_md_for_tm.ucast_egress_port", "standard_metadata.egress_spec")
		new_contents.gsub!("mcast_grp_a", "mcast_grp")
		new_contents.each_line do |line|
			new_contents.gsub!(line, "") if line.include? "tofino"
		end
		File.open(file_name, "w") {|file| file.puts new_contents }
	end
end


include CamusPostProcessing
include Config

# rules_file 		= "#{g "base_directory"}examples/queries/itch_rules.txt" 
# rules_file 		= "#{g "base_directory"}generated/queries/s_core_1_1.txt" 
# base_name 		= "#{g "output_directory"}ruby_g"
# p4_output 		= "#{g "output_directory"}ruby_g.p4"
# input_template 	= "#{g "base_directory"}examples/itch.p4"
topology_file 	= "#{g "base_directory"}examples/cdn_topo.json"



# Config.execute_camus rules_file, base_name, p4_output, input_template
Config.load_topology topology_file




