import "io"

manifest {
    disc_number = 1,
    words_per_block = 128,
    bytes_per_word = 4,
    file_size_words = 1,
    file_name_words = 8,
    max_file_name_chars = 32,
    metadata_block_size = 1
}

// Structure of a file header chunk.
manifest {
    offset_size = 0,
    offset_used_size = 1,
    offset_file_name = 2,
    // offset_file_name + file_name_words
    offset_data = 10 }

static {
    max_block = 0,
    availspace = 0,
    writefile = 0,
    readfile = 0,
    writeptr = 0,
    readptr = 0
}

// Because of the way we handle file descriptors (i.e. we don't) this doesn't
// need to do anything besides reset the pointers.
let close(faddr) be {
    if faddr = writefile {
        writefile := 0;
        writeptr := 0;
        resultis 0; }
    if faddr = readfile {
        readfile := 0;
        readptr := 0;
        resultis 0; }

    out("invalid file...hasn't been opened yet\n");
    resultis -1 }

// TODO--first call on open to find the start address, then set size fields
let delete(name) be {
    let buf = vec words_per_block;

    // Get the starting address of the file
    let addr = open(name, 'w');
    if addr = -1 then {
        out("could not delete file %s\n", name);
        resultis -1; }

    //devctl(DC_DISC)
}

// TODO--check size, get chunk
let read(ptr, dest, bytes) be {}

// TODO
let write(addr, src) be {}

// TODO--size in words
let create(fn, size) be {
    let buf = vec words_per_block;
    let addr = 0;
    let name = "";
    let tmp_size = 0;

    // Now represents the total number of words we need for the file
    size +:= file_size_words + file_size_words + file_name_words;
    // Convert into the number of blocks we need to represent
    size := (((size - 1) / words_per_block) + 1);

    while addr <= max_block do {
        tmp_size := buf ! offset_used_size;

        // If we're at end of used space, check if there's enough space
        if tmp_size = -1 then {
            if (tmp_size + size) <= max_block then resultis addr;
            resultis -1;
        }

        // If the disc space of this is 0, check if the disc space is good
        if tmp_size = 0 then {
            if (buf ! offset_size) <= size then resultis addr;
        }

        // Otherwise, continue to traverse
        addr +:= buf ! offset_size;
    }

    resultis -1 }

// Compare null-terminated strings a and b
// Returns 0 if equal, +/-1 if not
let strcmp(a, b) be {
    for i = 0 to max_file_name_chars do {
        let ac = byte i of a;
        let bc = byte i of b;
        if ac /= bc then resultis -1;
        if ac = 0 /\ bc = 0 then resultis 0; }

    resultis 1 }

// size is given in bytes
let memcpy(dest, src, size) be
    for i = 0 to size do
        dest ! i := src ! i;

// Returns address of file start in memory or -1 if not found.
// Pretty much acts like a linear find().
let open(fn, mode) be {
    let buf = vec words_per_block;
    let file_start = 0;
    let size = 0;
    let name;

    while file_start <= max_block do {
        devctl(DC_DISC_READ, disc_number, file_start, metadata_block_size, buf);
        // Get size field
        size := buf ! offset_size;
        if size = -1 then resultis -1;
        // Get name field
        name := buf ! offset_file_name;
        if strcmp(name, fn) = 0 then resultis file_start;
        // Keep checking at next file
        file_start +:= size;
    }

    resultis -1 }

// Setup size constants and consistent block structure.
let setup_fs() be {
    let empty = vec words_per_block;

    // Get the total usable size of the disc.
    max_block := devctl(DC_DISC_CHECK, disc_number);
    if max_block < 1 then {
        outs("dc_disc_check: got disc 1 size as 0\n");
        resultis -1; }

    // Set the initial block to be unoccupied.
    // Note: empty will not be initialized...assume contents past size field
    // will not be inspected.
    empty ! offset_size      := -1;
    empty ! offset_used_size := -1;
    if devctl(DC_DISC_WRITE, disc_number, metadata_block_size, empty) < 0 then {
        outs("dc_disc_write: could not write initial chunk\n");
        resultis -1; }

    resultis 0 }

let start() be {
    let x = create("README.txt", 10);
    return }
