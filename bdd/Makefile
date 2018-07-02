
all: bdd.native

bdd.byte: bdd.ml
	ocamlfind ocamlc -g -annot -g -o bdd.byte bdd.ml -package core -linkpkg -thread

bdd.native : bdd.ml
	ocamlfind ocamlopt -g -annot -g -o bdd.native bdd.ml -package core -linkpkg -thread

run: bdd.native
	./bdd.native

show: run
	dot -Tpng out.dot | display

tidy:
	rm -f *.cmo *.cmi *.annot

clean: tidy
	rm -f bdd.native bdd.byte
