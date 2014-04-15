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
    max_number_blocks = 6000 }

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

// Size given in words
let memcpy(dest, src, size) be
    for i = 0 to size do
        dest ! i := src ! i;

// Returns address of file start in memory or -1 if not found.
let find(fn) be {
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

let open(fn, mode) be {
    let addr = find(fn);
    if addr = -1 then resultis -1;

    if mode = 'w' then  {
        if writefile /= 0 then {
            out("file already open\n");
            resultis -1; }
        writefile := addr;
        writeptr := 0;
    }
    if mode = 'r' then  {
        if readfile /= then {
            out("file already open\n");
            resultis -1; }
        readfile := addr;
        readptr := 0;
    }

    resultis addr }

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

// First call on open to find the start address, then set size fields
let delete(name) be {
    let buf = vec words_per_block;

    // Get the starting address of the file
    let addr = find(name);
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

// TODO
let write(addr, src) be {
    out("%d %d %d\n", src ! 0, src ! 1, src ! 2);
    resultis 0 }

// Helper function for create() to write file metadata
let write_metadata(addr, fn, disc_size_blocks, used_size_words) be {
    let buf = vec words_per_block;
    let ch;
    buf ! offset_size      := disc_size_blocks;
    buf ! offset_used_size := used_size_words;
    buf ! offset_file_name := fn; // TODO: test

    out("creating at addr %d with sizes blocks %d, words %d\n", addr, disc_size_blocks, used_size_words);
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

        out("words needed: %d blocks needed: %d\nblock's disc: %d block's used: %d\n",
            word_size, block_size, disc_size, used_size);

        // If we're at end of used space, check if there's enough space
        test used_size = -1 then {
            if (addr + block_size - 1) < max_number_blocks then {
                // Split if necessary
                if (max_number_blocks - addr - block_size + 1) > 0 then
                    write_metadata(addr + block_size, "EMPTY",
                        max_number_blocks - addr - block_size + 1, -1);
                write_metadata(addr, fn, block_size, word_size);
                resultis addr; }
            // There is no space and we've traversed everything.
            resultis -1;
        // If the used space of this is 0, check if the disc space is good
        } else test used_size = 0 then {
            if disc_size <= block_size then {
                // Split if necessary
                // TODO: test
                if (disc_size - block_size) > 0 then
                    write_metadata(addr + block_size,
                        "EMPTY", disc_size - block_size, 0);
                write_metadata(addr, fn, block_size, word_size);
                resultis addr; }
        // Otherwise, continue to traverse
        } else {
            addr +:= disc_size; } }

    resultis -1 }

let setup_fs() be {
    // Set the initial block to be unoccupied.
    write_metadata(filesystem_root, "INITIAL", max_number_blocks, -1);

    resultis 0 }

let start() be {
    let data = table 3, 1, 4, 1;
    let result = vec 4;
    let f;
    setup_fs();

    create("README.txt", 32);

    f := open("README.txt", 'w');
    if f = -1 {
        outs("could not open\n");
        return;
    }

    write(f, data, 3);
    close(f);

    f := open("README.txt", 'r');
    if f = -1 {
        outs("could not open\n");
        return;
    }
    read(f, result, 3);
    close(f);

    out("3 1 4 1 =? %d %d %d\n", result ! 0, result ! 1, result ! 2, result ! 3);

    return }
