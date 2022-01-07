require 'fileutils'
require 'yaml'
require 'set'

@out_directory = "./out"
@dataset_directory = nil
@main_source_dir = nil
delete_out_directory = false

unless ARGV.empty?
	ARGV.each_with_index do |arg, index|
		@main_source_dir = ARGV[index + 1] if arg.eql? "-src"
		@dataset_directory = ARGV[index + 1] if arg.eql? "-datasets"
		delete_out_directory = true if arg.eql? "-f"
	end
	raise "invalid arguments" unless @dataset_directory and @main_source_dir
else
	puts "Invalid number of arguments!"
	puts "Usage: ruby make_experiments.rb [-f] <path/to/main_source>"
	return
end

if (File.exist? @out_directory) && !delete_out_directory
	puts "output directory already existed! Use '-f' to force deleting it"
	return
else
	FileUtils.rm_rf(@out_directory)
	FileUtils.rm(@runner_sh_file) rescue {}
	FileUtils.mkdir(@out_directory)
end

def load_nodes ds
	ds = @dataset_directory + ds
	nodes = {}
	File.readlines(ds).each do |line|
		line.strip!
		next if line[0] == '#'
		u = line.split[0]
		v = line.split[1]
		unless nodes.key? u
			nodes[u] = 0
		end
		unless nodes.key? v
			nodes[v] = 0
		end

		nodes[u] =  nodes[u] + 1
		nodes[v] =  nodes[v] + 1
	end
	nodes
end

def make_the_experiment distro, attr_size, conj_size, num_query, alpha, experiment_id, dataset, num_sub
	dir = @out_directory + "/old_num_sub#{num_sub}attr_size_#{attr_size}_num_query_#{num_query}_alpha_#{alpha}_experiment_#{experiment_id}_ds_#{dataset}/"
	puts "dir: #{dir}"
	FileUtils.mkdir dir
	File.open("#{dir}vars.txt", 'w') { |file| 
		file.puts("dataset: #{dataset}")
		file.puts("distro: #{distro}")
		file.puts("attr_size: #{attr_size}")
		file.puts("conj_size: #{conj_size}")
		file.puts("num_query: #{num_query}")
		file.puts("alpha: #{alpha}")
		file.puts("experiment: #{experiment_id}")
	}

	all_nodes = load_nodes(dataset)

	run_sh = "#{dir}run_exp.sh"
	FileUtils.cp_r "ssbg_camus.py", dir
	FileUtils.cp_r "SpanningTree.java", dir
	FileUtils.cp_r "itch.v16.p4", dir
	FileUtils.cp_r (@dataset_directory + dataset), dir
	File.open(run_sh, 'w') { |file| 
		file.puts "#!/bin/bash"
		# file.puts "cd #{Dir.pwd}"
		# file.puts "cd #{dir}"
		file.puts "mkdir -p queries" 
		file.puts "mkdir -p routing" 

		
		nodes_with_query = {}
		graph_size = all_nodes.keys.size
		while true 
			nodes_with_query[rand(graph_size)] = 'true'
			break if nodes_with_query.size > num_sub/num_query
		end

		all_nodes.keys.each_with_index do |node, index|
			# all_nodes[node] --> degree of the node in the original graph!
			if nodes_with_query.key? index
				file.puts("python2.7 ssbg_camus.py #{distro} --attr-space-size #{attr_size + 1} --disj-size 1 --conj-size #{conj_size + 1} --messages 0 --filters #{num_query} > queries/#{node}.query")
			end
		end
		file.puts "javac SpanningTree.java; java -Xmx8560m SpanningTree #{dataset} tree.txt" 
		file.puts "mkdir table-entries" 
		file.puts "find ./routing/ -name \"*filters\" -printf '~/camus-compiler/camus.exe -rules ./routing/%f -rt-out ./table-entries/%f itch.v16.p4; wc -l ./table-entries/%f*commands.txt >> number_table_entries.txt; rm ./table-entries/%f*txt;  \\0' | xargs -L1 -0 -P3 bash -c"
		file.puts "cat number_table_entries.txt | awk '{ print $1 }' >> number_table_entries_trimed.txt"
		file.puts "sort -rn number_table_entries_trimed.txt > sorted_table_entries.txt"
		file.puts "touch result.sql"
		file.puts "MAX=`head -n 1 sorted_table_entries.txt`"
		file.puts "echo -n 'INSERT INTO gen1 (ds, num_sub, attr_size, num_query, table_entry) VALUES (d1smart, #{num_sub}, #{attr_size}, #{num_query}, ' > result.sql"
		file.puts "echo -n $MAX >> result.sql"
		file.puts "echo ');' >> result.sql"
		file.puts "rm -rf routing"
		file.puts "rm -rf table-entries"
		file.puts "rm -rf queries"
	}

	FileUtils.chmod 0755, run_sh

	# creating the src and dst files!


end

attr_space_size_array = [2]
number_of_queries_array = [1,10]
alpha_array = [1]
number_of_subscribers = [200, 400, 750, 1000]


2.times do |experiment_id|
	Dir.foreach(@dataset_directory) do |ds|
		next if ds == '.' or ds == '..' or !ds.include? 'd2' 
		attr_space_size_array.each do |attr_size|
			number_of_queries_array.each do |num_query|
				alpha_array.each do |alpha|
					number_of_subscribers.each do |num_sub|
						conj_size = attr_size
						make_the_experiment "--zipf", attr_size, conj_size, num_query, alpha, experiment_id, ds, num_sub
					end
				end
			end
		end
	end
end
