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


unless ARGV.empty?
	topology_file 	= ARGV[0]
	Config.load_topology topology_file
else
	puts "Invalid number of arguments!"
	puts "Usage: ruby main.rb path_to_topology_file"
end




