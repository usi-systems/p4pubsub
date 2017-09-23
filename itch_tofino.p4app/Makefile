
all: add_order.itch

add_order.itch:
	../itch_tools/itch_gen.py -f Stock=ABC > add_order.itch
	../itch_tools/itch_gen.py -f Stock=XYZ >> add_order.itch

clean:
	rm -f add_order.itch
