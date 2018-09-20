cd /home/ali/p4pubsub/itch_tools
./nasdaq_binary_file.py -c 10 -f Price=31 -S uniform dump_0.bin
./replay -c 10 -o ar -R 10 dump_0.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=27 -S uniform dump_1.bin
./replay -c 10 -o ar -R 10 dump_1.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_2.bin
./replay -c 10 -o ar -R 10 dump_2.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=20 -S uniform dump_3.bin
./replay -c 10 -o ar -R 10 dump_3.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=21 -S uniform dump_4.bin
./replay -c 10 -o ar -R 10 dump_4.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=22 -S uniform dump_5.bin
./replay -c 10 -o ar -R 10 dump_5.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=24 -S uniform dump_6.bin
./replay -c 10 -o ar -R 10 dump_6.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=5 -S uniform dump_7.bin
./replay -c 10 -o ar -R 10 dump_7.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=28 -S uniform dump_8.bin
./replay -c 10 -o ar -R 10 dump_8.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=21 -S uniform dump_9.bin
./replay -c 10 -o ar -R 10 dump_9.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=6 -S uniform dump_10.bin
./replay -c 10 -o ar -R 10 dump_10.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=28 -S uniform dump_11.bin
./replay -c 10 -o ar -R 10 dump_11.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_12.bin
./replay -c 10 -o ar -R 10 dump_12.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=7 -S uniform dump_13.bin
./replay -c 10 -o ar -R 10 dump_13.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_14.bin
./replay -c 10 -o ar -R 10 dump_14.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=24 -S uniform dump_15.bin
./replay -c 10 -o ar -R 10 dump_15.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=25 -S uniform dump_16.bin
./replay -c 10 -o ar -R 10 dump_16.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_17.bin
./replay -c 10 -o ar -R 10 dump_17.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=25 -S uniform dump_18.bin
./replay -c 10 -o ar -R 10 dump_18.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=10 -S uniform dump_19.bin
./replay -c 10 -o ar -R 10 dump_19.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=4 -S uniform dump_20.bin
./replay -c 10 -o ar -R 10 dump_20.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_21.bin
./replay -c 10 -o ar -R 10 dump_21.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=16 -S uniform dump_22.bin
./replay -c 10 -o ar -R 10 dump_22.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=19 -S uniform dump_23.bin
./replay -c 10 -o ar -R 10 dump_23.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=17 -S uniform dump_24.bin
./replay -c 10 -o ar -R 10 dump_24.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=30 -S uniform dump_25.bin
./replay -c 10 -o ar -R 10 dump_25.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=15 -S uniform dump_26.bin
./replay -c 10 -o ar -R 10 dump_26.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=22 -S uniform dump_27.bin
./replay -c 10 -o ar -R 10 dump_27.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=2 -S uniform dump_28.bin
./replay -c 10 -o ar -R 10 dump_28.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=16 -S uniform dump_29.bin
./replay -c 10 -o ar -R 10 dump_29.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=19 -S uniform dump_30.bin
./replay -c 10 -o ar -R 10 dump_30.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=9 -S uniform dump_31.bin
./replay -c 10 -o ar -R 10 dump_31.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=7 -S uniform dump_32.bin
./replay -c 10 -o ar -R 10 dump_32.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=12 -S uniform dump_33.bin
./replay -c 10 -o ar -R 10 dump_33.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=27 -S uniform dump_34.bin
./replay -c 10 -o ar -R 10 dump_34.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=17 -S uniform dump_35.bin
./replay -c 10 -o ar -R 10 dump_35.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=29 -S uniform dump_36.bin
./replay -c 10 -o ar -R 10 dump_36.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=3 -S uniform dump_37.bin
./replay -c 10 -o ar -R 10 dump_37.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=3 -S uniform dump_38.bin
./replay -c 10 -o ar -R 10 dump_38.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=11 -S uniform dump_39.bin
./replay -c 10 -o ar -R 10 dump_39.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=31 -S uniform dump_40.bin
./replay -c 10 -o ar -R 10 dump_40.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=5 -S uniform dump_41.bin
./replay -c 10 -o ar -R 10 dump_41.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=26 -S uniform dump_42.bin
./replay -c 10 -o ar -R 10 dump_42.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=11 -S uniform dump_43.bin
./replay -c 10 -o ar -R 10 dump_43.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=21 -S uniform dump_44.bin
./replay -c 10 -o ar -R 10 dump_44.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_45.bin
./replay -c 10 -o ar -R 10 dump_45.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_46.bin
./replay -c 10 -o ar -R 10 dump_46.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=25 -S uniform dump_47.bin
./replay -c 10 -o ar -R 10 dump_47.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_48.bin
./replay -c 10 -o ar -R 10 dump_48.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=31 -S uniform dump_49.bin
./replay -c 10 -o ar -R 10 dump_49.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=14 -S uniform dump_50.bin
./replay -c 10 -o ar -R 10 dump_50.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=2 -S uniform dump_51.bin
./replay -c 10 -o ar -R 10 dump_51.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=29 -S uniform dump_52.bin
./replay -c 10 -o ar -R 10 dump_52.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=5 -S uniform dump_53.bin
./replay -c 10 -o ar -R 10 dump_53.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=11 -S uniform dump_54.bin
./replay -c 10 -o ar -R 10 dump_54.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=8 -S uniform dump_55.bin
./replay -c 10 -o ar -R 10 dump_55.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=4 -S uniform dump_56.bin
./replay -c 10 -o ar -R 10 dump_56.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=13 -S uniform dump_57.bin
./replay -c 10 -o ar -R 10 dump_57.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_58.bin
./replay -c 10 -o ar -R 10 dump_58.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=17 -S uniform dump_59.bin
./replay -c 10 -o ar -R 10 dump_59.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=13 -S uniform dump_60.bin
./replay -c 10 -o ar -R 10 dump_60.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=14 -S uniform dump_61.bin
./replay -c 10 -o ar -R 10 dump_61.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=19 -S uniform dump_62.bin
./replay -c 10 -o ar -R 10 dump_62.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=15 -S uniform dump_63.bin
./replay -c 10 -o ar -R 10 dump_63.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=28 -S uniform dump_64.bin
./replay -c 10 -o ar -R 10 dump_64.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=9 -S uniform dump_65.bin
./replay -c 10 -o ar -R 10 dump_65.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=29 -S uniform dump_66.bin
./replay -c 10 -o ar -R 10 dump_66.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=2 -S uniform dump_67.bin
./replay -c 10 -o ar -R 10 dump_67.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=11 -S uniform dump_68.bin
./replay -c 10 -o ar -R 10 dump_68.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=16 -S uniform dump_69.bin
./replay -c 10 -o ar -R 10 dump_69.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=5 -S uniform dump_70.bin
./replay -c 10 -o ar -R 10 dump_70.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=18 -S uniform dump_71.bin
./replay -c 10 -o ar -R 10 dump_71.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=12 -S uniform dump_72.bin
./replay -c 10 -o ar -R 10 dump_72.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=25 -S uniform dump_73.bin
./replay -c 10 -o ar -R 10 dump_73.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=20 -S uniform dump_74.bin
./replay -c 10 -o ar -R 10 dump_74.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=19 -S uniform dump_75.bin
./replay -c 10 -o ar -R 10 dump_75.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=12 -S uniform dump_76.bin
./replay -c 10 -o ar -R 10 dump_76.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=17 -S uniform dump_77.bin
./replay -c 10 -o ar -R 10 dump_77.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=16 -S uniform dump_78.bin
./replay -c 10 -o ar -R 10 dump_78.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=30 -S uniform dump_79.bin
./replay -c 10 -o ar -R 10 dump_79.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=14 -S uniform dump_80.bin
./replay -c 10 -o ar -R 10 dump_80.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_81.bin
./replay -c 10 -o ar -R 10 dump_81.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=2 -S uniform dump_82.bin
./replay -c 10 -o ar -R 10 dump_82.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=30 -S uniform dump_83.bin
./replay -c 10 -o ar -R 10 dump_83.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=3 -S uniform dump_84.bin
./replay -c 10 -o ar -R 10 dump_84.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=18 -S uniform dump_85.bin
./replay -c 10 -o ar -R 10 dump_85.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=16 -S uniform dump_86.bin
./replay -c 10 -o ar -R 10 dump_86.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=11 -S uniform dump_87.bin
./replay -c 10 -o ar -R 10 dump_87.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=27 -S uniform dump_88.bin
./replay -c 10 -o ar -R 10 dump_88.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=10 -S uniform dump_89.bin
./replay -c 10 -o ar -R 10 dump_89.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=21 -S uniform dump_90.bin
./replay -c 10 -o ar -R 10 dump_90.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=23 -S uniform dump_91.bin
./replay -c 10 -o ar -R 10 dump_91.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=17 -S uniform dump_92.bin
./replay -c 10 -o ar -R 10 dump_92.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=28 -S uniform dump_93.bin
./replay -c 10 -o ar -R 10 dump_93.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=24 -S uniform dump_94.bin
./replay -c 10 -o ar -R 10 dump_94.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=24 -S uniform dump_95.bin
./replay -c 10 -o ar -R 10 dump_95.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=31 -S uniform dump_96.bin
./replay -c 10 -o ar -R 10 dump_96.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=31 -S uniform dump_97.bin
./replay -c 10 -o ar -R 10 dump_97.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=1 -S uniform dump_98.bin
./replay -c 10 -o ar -R 10 dump_98.bin 10.0.0.1:1234
./nasdaq_binary_file.py -c 10 -f Price=21 -S uniform dump_99.bin
./replay -c 10 -o ar -R 10 dump_99.bin 10.0.0.1:1234
