require 'fileutils'


@result_dir = ""
unless ARGV.empty?
    ARGV.each do |arg|
        @result_dir = arg 
    end
    @result_dir = "#{@result_dir}/" unless @result_dir[-1].eql? "/"
else
	puts "Invalid number of arguments!"
    puts "Usage: ruby make_experiments.rb <path/to/result_folder>"
    return
end

def get_table_entries file
    `wc -l "#{file}"`.split(" ")[0]
end

puts "distro \t attr_size \t conj_size \t num_query \t switch_d \t time \t table_entries"
Dir[@result_dir + "*"].each do |_dir|
    dir = "#{_dir}/" unless _dir[-1].eql? "/"
    distro = attr_size = conj_size = num_query = nil


    File.readlines("#{dir}vars.txt").each do |line|
        key = line.split(" ")[0]
        value = line.split(" ")[1]

        distro = line.split(" ")[1] if line.split(" ")[0].start_with? "distro"
        attr_size = line.split(" ")[1] if line.split(" ")[0].start_with? "attr_size"
        conj_size = line.split(" ")[1] if line.split(" ")[0].start_with? "conj_size"
        num_query = line.split(" ")[1] if line.split(" ")[0].start_with? "num_query"
    end

    switch_id = nil
    time_ = nil
    File.readlines("#{dir}result.txt").each do |line|
        switch_id = /([a-z0-9_]+)\.txt/.match(line) || switch_id
        time_ = (line.split(" ")[-1] if line.start_with? "Made") || time_
        
        if(time_ && switch_id)
            switch_id = switch_id.to_s[0..-5]
            time_ = time_[0..-2]

            table_entries = get_table_entries "#{dir}out/commands/#{switch_id}_commands.txt"
            puts "#{distro} \t #{attr_size} \t #{conj_size} \t #{num_query} \t #{switch_id} \t #{time_} \t #{table_entries}"
            time_ = switch_id = nil
        end
    end

rescue
    next    
end