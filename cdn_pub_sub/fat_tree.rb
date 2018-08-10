require_relative 'config'

class FatTree
	attr_accessor :pod_size
	attr_accessor :host_size
	attr_accessor :mininet_config

	def initialize obj
		@pod_size = obj["target"]["pod_size"]
		@host_size = @pod_size * @pod_size * @pod_size / 4
		raise "Too big topology: #{pod_size}" if @pod_size > 255
		raise "Only even numbers are supported #{pod_size}" if @pod_size % 2 != 0

		mininet_raw
	end

	def mininet_raw
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

		puts switches.size()

		@mininet_config["multiswitch"] = multiswitch
		puts JSON.pretty_generate(@mininet_config)
	end

	def switch_command sw_id
		{commands: "#{g "output_directory"}commands/#{sw_id}.txt"}
	end

	def host_name switch_id, host_id
		"h_#{switch_id}_#{host_id}"
	end

	def agg_sw_name pod_id, switch_id
		"s_agg_#{pod_id}#{switch_id}"
	end

	def tor_sw_name pod_id, switch_id
		"s_tor_#{pod_id}#{switch_id}"
	end

	def core_sw_name core_id, switch_id
		"s_core_#{core_id}#{switch_id}"
	end

	def switches
		s = {}
		1.upto(@pod_size) do |p_id|
			@pod_size.downto(@pod_size/2 + 1) do |tor_sw_id|
				id = tor_sw_name(p_id, tor_sw_id)
				s[id] = switch_command id
			end
			1.upto(@pod_size/2) do |agg_sw_id|
				id = agg_sw_name(p_id, agg_sw_id)
				s[id] = switch_command id 
			end
		end
		1.upto(@pod_size/2) do |agg_sw_id|
			1.upto(@pod_size/2) do |core_sw_id|
				id = core_sw_name core_sw_id, agg_sw_id
				s[id] = switch_command id 
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
			@pod_size.downto(@pod_size/2 + 1) do |tor_sw_id|
				tor_switch_id = tor_sw_name p_id, tor_sw_id

				1.upto(@pod_size/2) do |host_id|
					host_id = host_name tor_sw_id, host_id
					l << [tor_switch_id, host_id]
				end

				1.upto(@pod_size/2) do |agg_sw_id|
					agg_switch_id = agg_sw_name p_id, agg_sw_id
					l << [agg_switch_id, tor_switch_id]
				end
			end
		end

		1.upto(@pod_size) do |p_id|
			1.upto(@pod_size/2) do |agg_sw_id|
				agg_switch_id = agg_sw_name p_id, agg_sw_id
				1.upto(@pod_size/2) do |core_sw_id|
					core_switch_id = core_sw_name core_sw_id, agg_sw_id
					l << [agg_switch_id, core_switch_id]
				end
			end
		end


		l
	end
end

