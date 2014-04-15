import "io"

manifest {
    disc_number = 1,
    words_per_block = 128,
    bytes_per_word = 4,
    file_size_words = 1,
    file_name_words = 8,
    max_file_name_bytes = 256, // 32 chars
    metadata_block_size = 1,
    filesystem_root = 1, // NB: this is 1-indexed
    max_number_blocks = 6000
}

// Structure of a file header chunk.
manifest {
    offset_size = 0,
    offset_used_size = 1,
    offset_file_name = 2,
    // offset_file_name + file_name_words
    offset_data = 10 }

static {
    writefile = 0,
    readfile = 0,
    writeptr = 0,
    readptr = 0 }


// Compare null-terminated strings a and b
// Returns 0 if equal, +/-1 if not
let strcmp(a, b) be {
    for i = 0 to max_file_name_bytes do {
        let ac = byte i of a;
        let bc = byte i of b;
        if ac /= bc then resultis -1;
        if ac = 0 /\ bc = 0 then resultis 0; }
    resultis 1 }

// Returns address of file start in memory or -1 if not found.
// Pretty much acts like a linear find().
let open(fn, mode) be {
    let buf = vec words_per_block;
    let addr = filesystem_root;
    let size, name;

    while addr <= max_number_blocks do {
        devctl(DC_DISC_READ, disc_number, addr, metadata_block_size, buf);
        size := buf ! offset_size;
        name := buf ! offset_file_name;

        out("looking at %d, with size %d, name %s\n", addr, size, name);

        if size = -1 then resultis -1;
        if strcmp(name, fn) = 0 then resultis addr;

        // Keep checking at next file
        addr +:= size; }

    resultis -1 }

// Because of the way we handle file descriptors (i.e. we don't) this doesn't
// need to do anything besides reset the pointers.
let close(addr) be {
    if addr = writefile then {
        writefile := 0;
        writeptr := 0;
        resultis 0; }
    if addr = readfile then {
        readfile := 0;
        readptr := 0;
        resultis 0; }

    out("close: invalid file...hasn't been opened yet\n");
    resultis -1 }

// TODO: implement
// First call on open to find the start address, then set size fields
let delete(name) be {
    let buf = vec words_per_block;

    // Get the starting address of the file
    let addr = open(name, 'w');
    if addr = -1 then {
        out("could not find file %s\n", name);
        resultis -1; }

    // Set metadata. Store used size as 0 leaving rest untouched.
    buf ! offset_used_size := 0;
    devctl(DC_DISC_WRITE, disc_number, addr, metadata_block_size, buf);

    resultis 0 }

// // TODO--check size, get chunk
// let read(ptr, dest, bytes) be {
//     resultis 0 }
//
// // TODO
// let write(addr, src) be {
//     resultis 0 }

// Helper function for create() to write file metadata
let write_metadata(addr, fn, disc_size_blocks, used_size_words) be {
    let buf = vec words_per_block;
    let ch;
    buf ! offset_size      := disc_size_blocks;
    buf ! offset_used_size := used_size_words;
    buf ! offset_file_name := fn; // TODO: check if good

    out("creating at addr %d with sizes %d, %d\n", addr, disc_size_blocks, used_size_words);
    devctl(DC_DISC_WRITE, disc_number, addr, metadata_block_size, buf);
    return }

// Traverse the file system for an available empty spot.
// If empty spot has over one excess chunk than we need than we split it.
// fn is a string conforming to filename limits, size is given in bytes.
let create(fn, size) be {
    let buf = vec words_per_block;
    let addr = filesystem_root;
    let block_size, word_size;
    let disc_size, used_size;

    // Now represents the total number of bytes we need for the file
    size +:= (file_size_words + file_size_words + file_name_words) * bytes_per_word;
    // Total number of words
    word_size := (((size - 1) / bytes_per_word) + 1);
    // Convert into the number of blocks we need.
    block_size := (((word_size - 1) / words_per_block) + 1);

    while addr <= max_number_blocks do {
        devctl(DC_DISC_READ, disc_number, addr, metadata_block_size, buf);
        disc_size := buf ! offset_size;
        used_size := buf ! offset_used_size;

        // If we're at end of used space, check if there's enough space
        test used_size = -1 then {
            if (addr + block_size - 1) < max_number_blocks then {
                // TODO: Check if we need to split
                write_metadata(addr, fn, block_size, word_size);
                resultis addr;
            }
            // There is no space and we've traversed everything.
            resultis -1;

        // If the used space of this is 0, check if the disc space is good
        } else test used_size = 0 then {
            if disc_size <= block_size then {
                // TODO: Check if we need to split
                write_metadata(addr, fn, block_size, word_size);
                resultis addr;
            }

        // Otherwise, continue to traverse
        } else {
            addr +:= disc_size;
        }
    }

    resultis -1 }

let setup_fs() be {
    // Set the initial block to be unoccupied.
    // Note: empty will not be initialized...assume contents past size field
    // will not be inspected.
    let buf = vec words_per_block;
    buf ! offset_size      := -1;
    buf ! offset_used_size := -1;

    if devctl(DC_DISC_WRITE, disc_number, filesystem_root,
            metadata_block_size, buf) < 0 then {
        outs("dc_disc_write: could not write initial chunk\n");
        resultis -1; }

    resultis 0 }

let start() be {
    let x, y;
    setup_fs();

    x := create("README.txt", 10);
    y := open("README.txt");
    //y := create("FILE2.txt", 64);
    out("got addrs as %d, %d\n", x, y);
    return }
