P4APP_IMAGE=p4lang/p4app:dev
P4APP_BIN=~/p4app/p4app

setup:
	cd ../int_tools && make
	cp ../int_tools/int-receiver .
	cp ../int_tools/int-sender .

run:
	P4APP_IMAGE=$(P4APP_IMAGE) $(P4APP_BIN) run .
