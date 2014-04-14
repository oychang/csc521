import "io"

manifest {
    words_per_block = 128
}



static {
    max_size = 0,
    availspace = 0,
    writeptr = 0,
    readptr = 0
}

// TODO
// 32 char names (31 usable) => 8 words
// ondisk size (1 word) + datasize (1 word) + name (8 words)
// let findfree(start, size) be {
//     resultis nil }

// TODO
let write(fn) be {
    resultis nil }

// TODO
let read(fn) be {
    resultis nil }

// Utility function to emulate C's open()
let open(fn, mode) be {
    if mode = 'w' then resultis write(fn);
    resultis read(fn) }

let setup_fs() be {
    let empty;

    // Get the total usable size of the disc
    max_size := devctl(DC_DISC_CHECK, 1);
    if max_size < 1 then {
        outs("dc_disc_check: got disc 1 size as 0\n");
        return; }

    // Set the initial block to be unoccupied
    empty := vec words_per_block;
    vec ! 0 := -1;
    if devctl(DC_DISC_WRITE, 1, 1, empty) < 0 then {
        outs("dc_disc_write: could not write initial chunk\n");
        return; }

    return }

let start() be {
    let f;

    setup_fs();

    f := open("readme.txt", 'w');

    // bksread = devctl(DC_DISC_READ, 1,
    firstblocknum, numblocks, memoryaddress);

    return }
