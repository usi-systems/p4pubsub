
all: netkafka_hooks.so

libnetkafka.o: libnetkafka.c
	gcc -c -fPIC -o libnetkafka.o libnetkafka.c

netkafka_client: libnetkafka.o netkafka_client.c
	gcc -o netkafka_client libnetkafka.o netkafka_client.c

netkafka_hooks.so: libnetkafka.o netkafka_hooks.c
	gcc -Wall -fPIC -shared libnetkafka.o netkafka_hooks.c -o netkafka_hooks.so -ldl

tidy:
	rm -f *.o

clean: tidy
	rm -f *.so
