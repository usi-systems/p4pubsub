cd /home/ali/p4pubsub/itch_tools
./nasdaq_binary_file.py -c 1 -f Price=20 -s GOOGL -S uniform dump.bin
./replay -c 1 -o ar -R 10 dump.bin 10.0.0.1:1234
