require 'fileutils'
require 'yaml'

@out_directory = "./out"
@main_source_dir = nil
delete_out_directory = false
@runner_sh_file = "./runner.sh"
@host_query_files_array = [
    "q141.txt", "q142.txt", "q131.txt", "q132.txt", "q241.txt", "q242.txt", "q231.txt", "q232.txt",
    "q341.txt", "q342.txt", "q331.txt", "q332.txt", "q441.txt", "q442.txt", "q431.txt", "q432.txt",
]

unless ARGV.empty?
    ARGV.each do |arg|
        @main_source_dir = arg unless arg.eql? "-f"
        delete_out_directory = true if arg.eql? "-f"
    end
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
    File.open(@runner_sh_file, 'w') { |file| file.puts "#!/bin/bash" }   
    FileUtils.chmod 0755, @runner_sh_file
end

def make_the_experiment distro, attr_size, conj_size, num_query
    dir = @out_directory + "/attr_size#{attr_size}conj_size#{conj_size}num_query#{num_query}/"
    FileUtils.mkdir dir
    File.open("#{dir}vars.txt", 'w') { |file| 
        file.puts("distro: #{distro}")
        file.puts("attr_size: #{attr_size}")
        file.puts("conj_size: #{conj_size}")
        file.puts("num_query: #{num_query}")
    }

    run_sh = "#{dir}run.sh"
    File.open(run_sh, 'w') { |file| 
        file.puts "#!/bin/bash"
        file.puts "cd #{Dir.pwd}"
        file.puts "cd #{dir}"
        file.puts "mkdir -p queries"
        @host_query_files_array.each do |host_file|
            file.puts("python ssbg_camus.py #{distro} --attr-space-size #{attr_size} --disj-size 1 --conj-size #{conj_size} --messages 0 --filters #{num_query} > queries/#{host_file}")
        end
    }

    # creating the src and dst files!
    src_dir = "#{dir}src/"
    out_dir = "#{dir}out/"
    FileUtils.chmod 0755, run_sh
    FileUtils.mkdir_p src_dir
    FileUtils.mkdir_p "#{out_dir}commands"
    FileUtils.mkdir_p "#{out_dir}queries"

    # main ruby files!
    FileUtils.cp "./cdn_topo.json", src_dir
    FileUtils.cp_r "#{@main_source_dir}/main.rb", src_dir
    FileUtils.cp_r "#{@main_source_dir}/fat_tree_local.rb", src_dir
    FileUtils.cp_r "#{@main_source_dir}/fat_tree_global.rb", src_dir
    FileUtils.cp_r "#{@main_source_dir}/config.rb", src_dir
    FileUtils.cp_r "ssbg_camus.py", dir

    # config.yaml
    config_file = YAML::load_file("./config.yaml")
    config_file["base_directory"] = dir
    config_file["output_directory"] = "./out/"
    File.open("#{src_dir}config.yaml", 'w') {|f| f.write config_file.to_yaml }

    File.open(run_sh, 'a') { |file| 
        file.puts "ruby ./src/main.rb ./src/cdn_topo.json ./src/config.yaml > result.txt"
    }
end

def make_runner_sh distro, attr_size, conj_size, num_query
    dir = @out_directory + "/attr_size#{attr_size}conj_size#{conj_size}num_query#{num_query}/"
    File.open("./runner.sh", 'a') { |file| 
        file.puts "#{dir}run.sh"
    }   
end


distribution_array = ["--zipf"]
attr_space_size_array = [4]
conj_size_array = [2]
number_of_queries_array = [30, 40, 50, 60]


distribution_array.each do |distro|
    attr_space_size_array.each do |attr_size|
        conj_size_array.each do |conj_size|
            number_of_queries_array.each do |num_query|
                make_the_experiment distro, attr_size, conj_size, num_query
                make_runner_sh distro, attr_size, conj_size, num_query
            end
        end
    end
end
