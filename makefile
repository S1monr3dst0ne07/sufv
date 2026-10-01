.PHONY: run compile bundle


run: compile
	./sufv

bundle: compile
	tar -cf release.tar sufv sufv.service index.html

compile:
	./yascl main.yap sufv


