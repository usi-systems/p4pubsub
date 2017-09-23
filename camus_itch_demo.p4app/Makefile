
all: tools add_order.itch generate_p4

tools:
	cd ../itch_tools && make
	cp ../itch_tools/replay ../itch_tools/receiver .

add_order.itch:
	../itch_tools/itch_gen.py -f Shares=1,Price=0 > add_order.itch
	../itch_tools/itch_gen.py -f Shares=0,Price=2 >> add_order.itch
	../itch_tools/itch_gen.py -f Shares=3,Price=4 >> add_order.itch
	../itch_tools/itch_gen.py -f Shares=1,Price=2 >> add_order.itch

clean:
	rm -f add_order.itch replay receiver generated_commands.txt generated_mcast_groups.txt p4src/generated_router.p4

generate_p4:
	cd ../compiler && make
	../compiler/main.native rules.txt
