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
        if ac /= bc then
            resultis -1;
        if ac = 0 /\ bc = 0 then resultis 0; }
    resultis 1 }

// Returns address of file start in memory or -1 if not found.
let find(fn) be {
    let buf = vec words_per_block;
    let addr = filesystem_root;
    let size, name;

    while addr <= max_number_blocks do {
        devctl(DC_DISC_READ, disc_number, addr, metadata_block_size, buf);
        size := buf ! offset_used_size;
        name := buf ! offset_file_name;

        if size = -1 then {
            resultis -1;}
        if strcmp(name, fn) = 0 then {
            resultis addr; }

        // Keep checking at next file
        addr +:= buf ! offset_size; }

    resultis -1 }

let open(fn, mode) be {
    let addr = find(fn);
    if addr = -1 then resultis -1;

    if mode = 'w' then  {
        if writefile /= 0 then {
            out("file already open\n");
            resultis -1; }
        writefile := addr;
        writeptr := offset_data; }
    if mode = 'r' then  {
        if readfile /= 0 then {
            out("file already open\n");
            resultis -1; }
        readfile := addr;
        readptr := offset_data; }

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

// Note that read() is essentially the less complicated version of write()
// in this implementation.
let read(addr, dest, words) be {
    let buf = vec words_per_block;
    let words_remaining = words;
    let active_block, words_to_read, block_offset;

    if addr /= readfile then {
        outs("cannot read...this file has not been opened\n");
        resultis -1; }

    while words_remaining > 0 do {
        // Find out which block we're in and how much we can write in it
        active_block := (readptr - 1) / words_per_block;
        block_offset := readptr rem words_per_block;
        words_to_read := words_per_block - block_offset;
        if words_remaining < words_to_read then
            words_to_read := words_remaining;

        // Read in chunk
        devctl(DC_DISC_READ, disc_number, addr + active_block, 1, buf);

        // Put in our allowed number of words
        for i = 0 to (words_to_read - 1) do {
            dest ! i := buf ! (i + block_offset);
        }

        readptr +:= words_to_read;
        words_remaining -:= words_to_read; }

    resultis 0 }

// TODO: check words does not overflow file's size
let write(addr, src, words) be {
    let buf = vec words_per_block;
    let words_remaining = words;
    let active_block, words_to_write, block_offset;

    if addr /= writefile then {
        outs("cannot write...this file has not been opened\n");
        resultis -1; }

    while words_remaining > 0 do {
        // Find out which block we're in and how much we can write in it
        active_block := (writeptr - 1) / words_per_block;
        block_offset := writeptr rem words_per_block;
        words_to_write := words_per_block - block_offset;
        if words_remaining < words_to_write then
            words_to_write := words_remaining;

        // Read in chunk
        devctl(DC_DISC_READ, disc_number, addr + active_block, 1, buf);

        // Put in our allowed number of words
        for i = 0 to (words_to_write - 1) do {
            buf ! (i + block_offset) := src ! i;
        }

        // Write back chunk
        devctl(DC_DISC_WRITE, disc_number, addr + active_block, 1, buf);

        writeptr +:= words_to_write;
        words_remaining -:= words_to_write; }

    resultis 0 }

// Helper function for create() to write file metadata
let write_metadata(addr, fn, disc_size_blocks, used_size_words) be {
    let buf = vec words_per_block;
    let ch;
    buf ! offset_size      := disc_size_blocks;
    buf ! offset_used_size := used_size_words;
    buf ! offset_file_name := fn; // TODO: test

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
    let a, b;
    let data = table 3, 1, 4, 1;
    let result = table 0, 0, 0, 0;
    setup_fs();

    create("README.txt", 32);

    a := open("README.txt", 'w');
    write(a, data, 4);
    close(a);

    // Awful syntax to avoid some segfault weirdness...
    read(open("README.txt", 'r'), result, 4);
    out("%d %d %d %d =? %d %d %d %d\n",
        data ! 0, data ! 1, data ! 2, data ! 3,
        result ! 0, result ! 1, result ! 2, result ! 3);

    delete("README.txt");

    return }
