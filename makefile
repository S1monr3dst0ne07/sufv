.PHONY: run compile bundle


run: compile
	./build

bundle: compile
	tar -cf release.tar main.yap compiler lib/ sufv.service 

compile:
	./compiler main.yap
	fasm -m 100000 build.asm build 
	chmod +x build


