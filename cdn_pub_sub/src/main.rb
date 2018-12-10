require 'json'
require_relative 'fat_tree'
require_relative 'config'

module CamusPostProcessing 
	def p4pp file_name
		text = File.read(file_name)
		new_contents = text.gsub("ig_intr_md_for_tm.ucast_egress_port", "standard_metadata.egress_spec")
		new_contents.gsub!("mcast_grp_a", "mcast_grp")
		
		new_contents.gsub!("ig_intr_md_for_tm", "intrinsic_metadata")
		new_contents.each_line do |line|
			new_contents.gsub!(line, "") if line.include? "tofino"
			new_contents.gsub!(line, "") if line.include? "@pragma"
		end
		File.open(file_name, "w") {|file| file.puts new_contents }
	end
end


include CamusPostProcessing
include Config


unless ARGV.empty?
	topology_file 	= ARGV[0]
	config_file 	= ARGV[1]
	Config.load_topology topology_file, config_file
else
	puts "Invalid number of arguments!"
	puts "Usage: ruby main.rb <path/to/cdn_topo.json> <path/to/config.yaml>"
end




