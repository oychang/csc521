import "io"

manifest {
    disc_number = 1,
    words_per_block = 128,
    file_size_words = 1,
    file_name_words = 8,
    metadata_block_size = 1
}

manifest {
    offset_size = 0,
    offsed_used_size = 1,
    offset_file_name = 2,
    max_file_name_chars = 32
}

static {
    max_block = 0,
    availspace = 0,
    writeptr = 0,
    readptr = 0
}

let create(name, size) be {}
let delete(name) be {}
let close() be {}

// TODO--size in words
let create(fn, size) be {
    let buf = vec words_per_block
    let addr = 0;
    let name = "";
    let tmp_size = 0;

    // Now represents the total number of words we need for the file
    size +:= file_size_words + file_size_words + file_name_words;
    // Convert into the number of blocks we need to represent
    size := (((size - 1) / words_per_block) + 1)

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
        if ac = 0 /\ bc = 0 then resultis 0;
    }

    resultis 1 }

// size is given in blocks
//let memcpy(dest, src, size) be {
//    size *:= words_per_block;
//    for i = 0 to size do {
//        byte i of dest := byte i of src;
//    }
//    return }

// Returns address of file start in memory or -1 if not found
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
    let empty;

    // Get the total usable size of the disc.
    max_blocks := devctl(DC_DISC_CHECK, disc_number);
    if max_blocks < 1 then {
        outs("dc_disc_check: got disc 1 size as 0\n");
        resultis -1;
    }

    // Set the initial block to be unoccupied.
    // Note: empty will not be initialized...assume contents past size field
    // will not be inspected.
    empty := vec words_per_block;
    empty ! offset_size := -1;
    empty ! offset_used_size := -1;
    if devctl(DC_DISC_WRITE, disc_number, metadata_block_size, empty) < 0 then {
        outs("dc_disc_write: could not write initial chunk\n");
        resultis -1;
    }

    resultis 0 }

let start() be {
    let f;

    if setup_fs() = -1 then return;
    f := open("readme.txt", 'w', 10);
    if f = nil then {
        outs("could not open file\n");
        return; }

    return }
