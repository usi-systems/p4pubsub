
all: tools add_order.itch

tools:
	cd ../itch_tools && make
	cp ../itch_tools/replay ../itch_tools/receiver .

add_order.itch:
	../itch_tools/itch_message.py -f Stock=ABC > add_order.itch
	../itch_tools/itch_message.py -f Stock=XYZ >> add_order.itch

clean:
	rm -f add_order.itch replay receiver
