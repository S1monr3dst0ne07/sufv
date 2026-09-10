

compile:
	./compiler main.yap
	fasm -m 100000 build.asm build 
	chmod +x build
	./build


