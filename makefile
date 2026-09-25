.PHONY: run compile bundle


run: compile
	./sufv

bundle: compile
	tar -cf release.tar sufv sufv.service index.html

compile:
	./compiler main.yap
	fasm -m 100000 build.asm sufv
	chmod +x sufv


