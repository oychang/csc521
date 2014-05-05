import "io"

export { getfn, load_program }

// Transforms a loaded in *.exe into a function
let getfn(loadaddr) be
  resultis loadaddr + 2 + ((loadaddr ! 1) bitand 0xffff)

// Loads in a *.exe file from the unix fs and puts it in the address given.
// Assume addess is valid (or we will overflow willingly).
let load_program(fn, addr) be {
  manifest { default_tape = 1, bytes_per_word = 4 }
  let bytes_read, total_words_read = 0;

  test devctl(DC_TAPE_LOAD, default_tape, fn, 'R') /= 1 then {
    outs("bad tape load\n");
    resultis false;
  } else if devctl(DC_TAPE_CHECK, default_tape) = 0 then {
    outs("tape no available");
    resultis false;
  }

  {
    bytes_read := devctl(DC_TAPE_READ, default_tape, addr + total_words_read);
    total_words_read +:= bytes_read / bytes_per_word;
  } repeatwhile bytes_read /= 0;

  devctl(DC_TAPE_UNLOAD, default_tape);
  resultis true
}
