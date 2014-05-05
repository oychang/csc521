default:
	bcpl tape && assemble tape
	bcpl fsutils && assemble fsutils
	bcpl syscall && assemble syscall
	prep shell

.PHONY: clean
clean:
	rm -f *.bcl *.obj *.ass
	rm -f *.exe *.disc
