import "io"

manifest {
    disc_number = 1,
    words_per_block = 128,
    file_size_words = 1,
    file_name_words = 8,
    metadata_block_size = 1
}

manifest {
    offset_size = 0
}

static {
    max_size = 0,
    availspace = 0,
    writeptr = 0,
    readptr = 0
}

// TODO
// let findfree(start, size) be {
//     resultis nil }

// TODO
// find empty space of size, make sure space on disc (split if have to)
// setup header fields
// return address
let open_w(fn, size) be {
    resultis nil }

// TODO
// traverse until find file or a size of -1
// return address if found or -1
let open_r(fn) be {
    let buf = vec words_per_block;
    let file_start_word = 0;

    while file_start_word <= max_size do {
        devctl(DC_DISC_READ, disc_number, 0, metadata_block_size, buf);

    }

    resultis nil }

// Utility function to emulate C's open()
let open(fn, mode, size) be {
    if mode = 'w' then resultis open_w(fn, size);
    resultis open_r(fn) }

// Setup size constants and consistent block structure.
let setup_fs() be {
    let empty;

    // Get the total usable size of the disc.
    max_size := devctl(DC_DISC_CHECK, disc_number);
    if max_size < 1 then {
        outs("dc_disc_check: got disc 1 size as 0\n");
        resultis -1; }

    // Set the initial block to be unoccupied.
    // Note: empty will not be initialized...assume contents past size field
    // will not be inspected.
    empty := vec words_per_block;
    vec ! offset_size := -1;
    if devctl(DC_DISC_WRITE, disc_number, metadata_block_size, empty) < 0 then {
        outs("dc_disc_write: could not write initial chunk\n");
        resultis -1; }

    resultis 0 }

let start() be {
    let f;

    if setup_fs() = -1 then return;
    f := open("readme.txt", 'w', 10);
    if f = nil then {
        outs("could not open file\n");
        return; }

    return }
