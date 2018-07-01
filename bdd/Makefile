
all: bdd.byte

bdd.byte: bdd.ml
	ocamlfind ocamlc -g -annot -g -o bdd.byte bdd.ml -package core -linkpkg -thread 

run: bdd.byte
	./bdd.byte

show: run
	dot -Tpng out.dot | display

tidy:
	rm -f *.cmo *.cmi *.annot

clean: tidy
	rm -f bdd.byte
