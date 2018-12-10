require_relative 'config'
require 'fileutils'

class FatTree
	attr_accessor :pod_size
	attr_accessor :host_size
	attr_accessor :host_names
	attr_accessor :obj

	def initialize obj
		@obj = obj
		@host_names = {}
		@pod_size = obj["target"]["pod_size"]
		@host_size = @pod_size * @pod_size * @pod_size / 4
		raise "Too big topology: #{pod_size}" if @pod_size > 255
		raise "Only even numbers are supported #{pod_size}" if @pod_size % 2 != 0

		mininet_config
		handle_queries
		execute_all_camus
	end

	def execute_all_camus
		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_id|
				sw_name = tor_sw_name p_id, tor_id
				query_file = switch_queries sw_name
				run_camus query_file, sw_name
			end
			1.upto(@pod_size/2) do |agg_id|
				query_file = switch_queries(agg_sw_name p_id, agg_id)
				run_camus query_file, (agg_sw_name p_id, agg_id)
			end
		end

		1.upto(@pod_size/2) do |agg_sw_id|
			1.upto(@pod_size/2) do |core_sw_id|
				query_file = switch_queries(core_sw_name core_sw_id, agg_sw_id)
				run_camus query_file, (core_sw_name core_sw_id, agg_sw_id)
			end
		end
	end

	def run_camus rules_file, base_name
		b_name 			= "#{g "output_directory"}commands/#{base_name}"
		camus_p4_output = "#{g "output_directory"}camus.p4"
		main_p4_output 	= "#{g "output_directory"}ruby_g.p4"
		itch_p4_file 	= "#{g "itch_p4"}"

		Config.execute_camus rules_file, b_name, camus_p4_output, itch_p4_file
		FileUtils.cp(itch_p4_file, main_p4_output);
		CamusPostProcessing.p4pp main_p4_output
	end

	def handle_queries
		hosts = @obj["hosts"]
		hosts.each do |key, value|
			raise "invalid host name: #{key}" unless @host_names.has_key? key
			@host_names[key][:file] = hosts[key]["queries"]
		end

		delete_old_queries_files
		fill_queries_files
	end

	def delete_old_queries_files
		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_id|
				File.delete(switch_queries(tor_sw_name p_id, tor_id)) rescue {}
			end
			1.upto(@pod_size/2) do |agg_id|
				File.delete(switch_queries(agg_sw_name p_id, agg_id)) rescue {}
			end
		end
		1.upto(@pod_size/2) do |agg_sw_id|
			1.upto(@pod_size/2) do |core_sw_id|
				File.delete(switch_queries(core_sw_name core_sw_id, agg_sw_id)) rescue {}
			end
		end
	end

	def fill_queries_files
		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_sw_id|
				fill_queries_tor p_id, tor_sw_id
			end
			1.upto(@pod_size/2) do |agg_sw_id|
				fill_queries_agg p_id, agg_sw_id
			end
		end

		1.upto(@pod_size/2) do |agg_sw_id|
			1.upto(@pod_size/2) do |core_sw_id|
				fill_queries_core core_sw_id, agg_sw_id
			end
		end
	end

	def fill_queries_tor pod_id, tor_id
		1.upto(@pod_size/2) do |host_id|
			h_file = @host_names["#{host_name pod_id, tor_id, host_id}"][:file]
			h_queries = File.open(h_file, "r").read

			File.open(switch_queries(tor_sw_name pod_id, tor_id), "a") do |file|
				h_queries.each_line do |l|
					file.puts "#{l.strip}: fwd(#{host_id});"
				end
			end

			uplink_port = (@pod_size/2 + 1)
			upward_query = "add_order.price < 99999999: fwd(#{uplink_port});"

			queries = File.open(switch_queries(tor_sw_name pod_id, tor_id), "r").read
			return if queries.include? upward_query
			File.open(switch_queries(tor_sw_name pod_id, tor_id), "a") do |file|
				file.puts upward_query
			end
						
		end
	end

	def fill_queries_agg pod_id, agg_id
		(@pod_size/2 + 1).upto(@pod_size) do |tor_id|
			intf_id = @pod_size - (tor_id - (@pod_size/2 + 1))

			1.upto(@pod_size/2) do |host_id|
				h_file = @host_names["#{host_name pod_id, tor_id, host_id}"][:file]
				h_queries = File.open(h_file, "r").read

				file_name_ = switch_queries(agg_sw_name pod_id, agg_id)
				File.open(file_name_, "a") do |file|
					h_queries.each_line do |l|
						file.puts "#{l.strip}: fwd(#{intf_id});"
					end
				end

				uplink_port = 1
				upward_query = "add_order.price < 99999999: fwd(#{uplink_port});"
				queries = File.open(file_name_, "r").read
				next if queries.include? upward_query
				File.open(file_name_, "a") do |file|
					file.puts upward_query
				end
			end
		end
	end

	def fill_queries_core core_id, agg_id
		1.upto(@pod_size) do |pod_id|
			(@pod_size/2 + 1).upto(@pod_size) do |tor_id|
				1.upto(@pod_size/2) do |host_id|
					h_file = @host_names["#{host_name pod_id, tor_id, host_id}"][:file]
					h_queries = File.open(h_file, "r").read

					File.open(switch_queries(core_sw_name core_id, agg_id), "a") do |file|
						h_queries.each_line do |l|
							file.puts "#{l.strip}: fwd(#{pod_id});"
						end
					end
				end	
			end
		end
	end

	def mininet_config
		@mininet_config = {}
		@mininet_config["program"] = "simple_router.p4"
  		@mininet_config["language"] = "p4-14"

  		multiswitch = {}
		multiswitch["bmv2_log"] = g "fat_tree_bmv2_log"
		multiswitch["pcap_dump"] = g "fat_tree_pcap_dump"
		multiswitch["auto-control-plane"] = g "fat_tree_auto_control_plane"
		multiswitch["cli"] = g "fat_tree_cli"


		multiswitch["links"] = links
		multiswitch["hosts"] = hosts
		multiswitch["switches"] = switches

		@mininet_config["targets"] = {multiswitch: multiswitch}

		File.open("#{g "output_directory"}p4app.json", "w") { |file| 
			file.puts JSON.pretty_generate(@mininet_config)
		}
	end

	def switch_command sw_id
		{
			commands: [
				"#{g "output_directory"}commands/#{sw_id}_ipv4.txt",
				"#{g "output_directory"}commands/#{sw_id}_commands.txt"
			],
			mcast_groups: "#{g "output_directory"}commands/#{sw_id}_mcast_groups.txt"
		}
	end

	def switch_queries sw_id
		"#{g "output_directory"}queries/#{sw_id}.txt"
	end

	def host_name pod_id, switch_id, host_id
		key = "h_#{pod_id}_#{switch_id}_#{host_id}"

		@host_names[key] = {} unless @host_names.has_key? key
		@host_names[key][:pod_id] = pod_id
		@host_names[key][:switch_id] = switch_id
		@host_names[key][:host_id] = host_id

		key
	end

	def agg_sw_name pod_id, switch_id
		"s_agg_#{pod_id}_#{switch_id}"
	end

	def tor_sw_name pod_id, switch_id
		"s_tor_#{pod_id}_#{switch_id}"
	end

	def core_sw_name core_id, switch_id
		"s_core_#{core_id}_#{switch_id}"
	end

	def tor_intf_mac pod_id, tor_id, host_id
		"00:ff:00:#{'%02x' % pod_id}:#{'%02x' % tor_id}:#{'%02x' % host_id}"
	end

	def agg_intf_mac agg_id, tor_id
		"00:77:00:88:#{'%02x' % agg_id}:#{'%02x' % tor_id}"
	end

	def core_intf_mac agg_id, tor_id
		"00:77:00:88:#{'%02x' % agg_id}:#{'%02x' % tor_id}"
	end

	def host_ip pod_id, tor_id, host_id
		"10.#{pod_id}.#{tor_id}.#{host_id}"
	end

	def host_mac pod_id, tor_id, host_id
		"00:aa:00:#{'%02x' % pod_id}:#{'%02x' % tor_id}:#{'%02x' % host_id}"
	end

	def fill_commands_tor pod_id, tor_id
		file_name = switch_command(tor_sw_name pod_id, tor_id)[:commands].first

		
		# puts "fileName: #{file_name}"

		File.open(file_name, "w") {|file| 
			1.upto(@pod_size/2) do |host_id|
				file.puts "table_add send_frame rewrite_mac 0x#{host_id} => #{tor_intf_mac pod_id, tor_id, host_id}"
				file.puts "table_add ipv4_lpm set_nhop #{host_ip pod_id, tor_id, host_id}/32 => #{host_ip pod_id, tor_id, host_id} 0x#{'%x' % host_id}"
				file.puts "table_add forward set_dmac 0x#{'%x' % host_id} => #{host_mac pod_id, tor_id, host_id}"

				file.puts "table_add icn_to_ip set_dip 0x#{'%x' % host_id} => #{host_ip pod_id, tor_id, host_id}"

				file.puts ""
			end

			# Currently, I just forward pakcets to the first upward interface! Since I don't know the 
			# swtich's mac address, I use a random value. Let's see if it works!!
			uplink_port = "0x#{'%02x' % (@pod_size/2 + 1)}"
			file.puts "table_add send_frame rewrite_mac #{uplink_port} => #{tor_intf_mac pod_id, tor_id, 0}"
			file.puts "table_add ipv4_lpm set_nhop 10.0.0.0/8 => 10.0.0.100 #{uplink_port}"
			file.puts "table_add forward set_dmac #{uplink_port} => #{tor_intf_mac pod_id, tor_id, 0}"


			file.puts  ""
		}
	end

	def fill_commands_agg pod_id, agg_id
		file_name = switch_command(agg_sw_name pod_id, agg_id)[:commands].first
		File.open(file_name, "w") {|file| 
			(@pod_size/2 + 1).upto(@pod_size) do |tor_id|
				intf_id = @pod_size - (tor_id - (@pod_size/2 + 1))
				file.puts "table_add send_frame rewrite_mac 0x#{tor_id} => #{agg_intf_mac agg_id, tor_id}"
				file.puts "table_add ipv4_lpm set_nhop #{host_ip pod_id, tor_id, 0}/24 => #{host_ip pod_id, tor_id, 0} 0x#{'%x' % intf_id}"
				file.puts "table_add forward set_dmac 0x#{'%x' % intf_id} => #{tor_intf_mac pod_id, tor_id, 0}"
				file.puts ""
			end

			# Currently, I just forward pakcets to the first upward interface! Since I don't know the 
			# swtich's mac address, I use a random value. Let's see if it works!!
			uplink_port = "0x1"
			file.puts "table_add send_frame rewrite_mac #{uplink_port} => #{agg_intf_mac pod_id, agg_id}"
			file.puts "table_add ipv4_lpm set_nhop 10.0.0.0/8 => 10.0.0.100 #{uplink_port}"
			file.puts "table_add forward set_dmac #{uplink_port} => #{core_intf_mac pod_id, agg_id}"


			file.puts  ""
		}
	end

	def fill_commands_core core_id, agg_id
		file_name = switch_command(core_sw_name core_id, agg_id)[:commands].first
		File.open(file_name, "w") {|file| 
			1.upto(@pod_size) do |pod_id|
				file.puts "table_add send_frame rewrite_mac 0x#{pod_id} => #{core_intf_mac pod_id, core_id}"
				file.puts "table_add ipv4_lpm set_nhop #{host_ip pod_id, 0, 0}/16 => #{host_ip pod_id, 0, 0} 0x#{'%x' % pod_id}"
				file.puts "table_add forward set_dmac 0x#{'%x' % pod_id} => #{tor_intf_mac pod_id, 0, 0}"
				file.puts ""
			end
		}
	end

	def switches
		s = {}
		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_sw_id|
				id = tor_sw_name(p_id, tor_sw_id)
				s[id] = switch_command id
				fill_commands_tor p_id, tor_sw_id
			end
			1.upto(@pod_size/2) do |agg_sw_id|
				id = agg_sw_name(p_id, agg_sw_id)
				s[id] = switch_command id 
				fill_commands_agg p_id, agg_sw_id
			end
		end
		1.upto(@pod_size/2) do |agg_sw_id|
			1.upto(@pod_size/2) do |core_sw_id|
				id = core_sw_name core_sw_id, agg_sw_id
				s[id] = switch_command id 
				fill_commands_core core_sw_id, agg_sw_id
			end
		end
		s
	end

	def hosts
		{}
	end

	def links
		l = []

		1.upto(@pod_size) do |p_id|
			1.upto(@pod_size/2) do |agg_sw_id|
				agg_switch_id = agg_sw_name p_id, agg_sw_id
				1.upto(@pod_size/2) do |core_sw_id|
					core_switch_id = core_sw_name core_sw_id, agg_sw_id
					l << [agg_switch_id, core_switch_id]
				end
			end
		end

		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_sw_id|
				tor_switch_id = tor_sw_name p_id, tor_sw_id

				1.upto(@pod_size/2) do |host_id|
					host_id = host_name p_id, tor_sw_id, host_id
					l << [tor_switch_id, host_id]
				end

				1.upto(@pod_size/2) do |agg_sw_id|
					agg_switch_id = agg_sw_name p_id, agg_sw_id
					l << [agg_switch_id, tor_switch_id]
				end
			end
		end

		l
	end
end

