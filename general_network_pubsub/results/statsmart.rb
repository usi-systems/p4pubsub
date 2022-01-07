graph = {}
degrees = {}
File.readlines("degreesmart.txt").each do |line|
	node = line.split(" ")[0]
	degree = line.split(" ")[1]
	node.strip!
	degrees[node] = degree.to_i
end
File.readlines("rawsmart.txt").each do |line|
	table_entry = line.split(" ")[0]
	node = line.split(".filter")[0].split("/")[-1]
	node.strip!
	graph[node] ||= []
	graph[node] << {:degree => degrees[node], :table_entry => table_entry.to_i}
end

File.open('d2smart.dat', 'w') do |file| 
	graph.each do |key, value|
		value.each do |v|
			file.puts("#{v[:degree]} #{v[:table_entry]} #{key}")
		end
	end
end