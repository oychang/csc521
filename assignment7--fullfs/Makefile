# Fuck Makefiles, especially non-GNU ones.
# There's a hidden python file in this directory that contains pseudo-make
# instructions. 

default:
	python .make

.PHONY: clean clean-submit
clean:
	rm -f *.bcl *.obj *.ass
clean-submit: clean
	rm -f *.exe

