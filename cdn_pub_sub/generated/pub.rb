valid_prices = [11, 12, 13, 14, 21, 22, 23, 24, 31, 32, 33, 34, 41, 42, 43, 44]

1000.times do 
	rnd = valid_prices.sample
	puts "./nasdaq_binary_file.py -c 10 -f Price=#{rnd} -S uniform dump_#{rnd}.bin"
    puts "./replay -c 10 -o ar -R 10 dump_#{rnd}.bin 10.0.0.1:1234"
end

