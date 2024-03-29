//=============================================================================
// Oliver Chang, April 2014, CSC521: Computer Operating Systems
// Assignment 4+: Implementing newvec & freevec
// http://rabbit.eng.miami.edu/class/een521/ass4-142.txt
//
//   ~~~~~~~~~~~~~~~~~~~~ Anatomy of a Chunk of Memory ~~~~~~~~~~~~~~~~~~~~~~
//   |======================================================================|
//   |             Header            | Data |             Footer            |
//   |-------------------------------|------|-------------------------------|
//   | FreePtr (Next) | Size / InUse | .... | FreePtr (Prev) | Size / InUse |
//   |======================================================================|
// Let the minimum amount of allocatable memory be 16 blocks
// Let each chunk of memory be divisible by 16, e.g. 16, 32, 48, 64, ...
// Let each chunk of memory be a node in a doubly linked list
// Let each node have a header and a footer
// Let the header be two words: a pointer to the next free & real size of block
// Let the footer be two words: a poitner the the previous free & real size
// TODO: Use a 5-bin exact-fit strategy:
// Bin1 = freelist of 16s,..., Bin4 = freelist of 64s, Bin5 = everything larger
// Usable size of the chunk = real size - 4
// All chunks will have an even size => last bit of size used for in-use flag
//=============================================================================

import "io"

manifest {
    // Offsets that correlate with the chunk diagram above
    node_next = 0,
    node_size = 1,
    node_prev = 2,
    // 2 word header, footer
    node_metadata_left = 2,
    node_metadata_right = 2,
    node_metadata_total = 4,
    node_min_size = 16 }

static {
    // Initial value that estimates program stack use
    hstart = 256,
    hsize = 0,
    headptr = nil }

let size(addr, n) be {
    // Setter. Assume that address is a valid chunk header and that we can
    // access up to addr + n - node_size words of memory to set the footer size.
    if numbargs() = 2 then {
        addr ! node_size := n;
        addr ! (n - node_size) := n;
        return;
    }

    // Getter. Assume address is a valid chunk and that header == footer size.
    // Assume that we will only have even sizes...the least significant bit
    // is used for status. Thus, most sizes will be literally represented as
    // off-by-one. The mask compensates for that.
    resultis ((addr ! node_size) bitand 0xfffffffe) }

let next(addr, nextaddr) be {
    // Setter. Assume addr is a valid chunk. nextaddr might be a valid
    // memory address for the header of a free chunk, in which case
    // we set that chunk's previous field, or nil, in which case we just stop
    // after setting this chunk's next field.
    if numbargs() = 2 then {
        addr ! node_next := nextaddr;
        if nextaddr /= nil then nextaddr ! (size(nextaddr) - node_prev) := addr;
        return;
    }

    // Getter. Do not assume that addr is valid (useful for chaining).
    if addr /= nil then resultis (addr ! node_next);
    resultis nil }

let prev(addr, prevaddr) be {
    let n;
    // Setter. Since the previous field is in the footer, we assume that
    // this chunk is valid and its size field has been set so we can get
    // to the previous field, the penultimate word of the chunk.
    // Behave identically to next() w.r.t. nil 2nd argument.
    if numbargs() = 2 then {
        n := size(addr);
        addr ! (n - node_prev) := prevaddr;
        if prevaddr /= nil then prevaddr ! node_next := addr;
        return;
    }

    // Getter. Check for nillness (like next()) for chaining reasons.
    if addr /= nil then {
        n := size(addr);
        resultis (addr ! (n - node_prev));
    }
    resultis nil }

let create(addr, chunksize, nextaddr, prevaddr) be {
    size(addr, chunksize);
    prev(addr, prevaddr);
    next(addr, nextaddr);
    resultis addr }

// Get the least significant bit of a 32-bit size word and compare to 1.
// If 1, then this node is in use. Otherwise, we're freee
let inuse(n) be
    resultis (n bitand 1)

// for example, f(33) = 48; f(14) = 16
// take advantage of fact that for x positive, ceil(n / 16) <=> (n-1)/16 + 1
let to_16_divisible(n) be
    resultis (((n - 1) / node_min_size) + 1) * node_min_size

// Split a single chunk into two smaller ones, a left chunk and a right chunk.
// We'll leave the left chunk as close to the original as possible so we
// only have to change the previous pointer in the freelist.
// Assume we're about to allocate the right chunk. This means that
// lsize <= rsize and there will be no freelist pointers for rchunk.
let split(addr, lsize, rsize) be {
    // Reassign all information for the left node.
    create(addr, lsize, next(addr), prev(addr));
    // Return the location of the right node for use in further allocation.
    resultis create(addr + lsize, rsize, nil, nil) }

// Collapse down leftchunk and rightchunk into one chunk and return the
// address that points to the header section of the left, newly combined chunk.
let coalesce(lchunk, rchunk) be {
    let lsize, rsize, totalsize;
    let newnext, newprev;
    let lprev, rnext;
    // Get the new size of the chunk to create
    lsize := size(lchunk);
    rsize := size(rchunk);
    totalsize := lsize + rsize;

    // We have four node pointers to change:
    // a) leftchunk's next becomes newchunk's next
    newnext := next(lchunk);
    // b) rightchunk's previous becomes newchunk's previous
    newprev := prev(rchunk);
    // c) leftchunk's previous's next becomes rightchunk's next's previous
    lprev := next(prev(lchunk));
    if (lprev /= nil) /\ (next(rchunk) /= nil) then prev(next(rchunk), lprev);
    // d) rightchunk's next's previous becomes leftchunk's previous's next
    rnext := prev(next(rchunk));
    if (rnext /= nil) /\ (prev(lchunk) /= nil) then next(prev(lchunk), rnext);

    resultis create(lchunk, totalsize, newnext, newprev) }

let firstfit_newvec(n) be {
    let chunk = headptr; // Where to start search for available chunks.

    let chunks; // Current search chunk size
    let reals = n + node_metadata_total;
    let lchunks, rchunks; // For use in splitting

    while chunk /= nil do {
        // Use a first-fit strategy to get the first chunk with size >= n
        chunks := size(chunk);
        // Check if in use and proper size
        if (inuse(chunks)) \/ (chunks < reals) then {
            chunk := next(chunk);
            loop;
        }

        // Check if worthwhile to split
        // Only split this block into two separate ones if, at a minimum,
        // we can create another 16 block.
        // Find out the sizes of the left and right chunks, both 16 divisible.
        if chunks >= (reals + node_min_size) then {
            rchunks := to_16_divisible(reals);
            lchunks := chunks - rchunks;
            chunk := split(chunk, lchunks, rchunks);
            chunks := rchunks;
        }

        // Check if we need to reposition `headptr`, which happens in the case
        // when we are returning the memory chunk referred to by the current
        // head pointer. Pass the buck to the next one after that (which
        // might be nil).
        if chunk = headptr then headptr := next(headptr);

        // Set the node to used (set to an odd number)
        size(chunk, chunks + 1);
        // Return pointer to user's data area.
        resultis (chunk + node_metadata_left);
    }

    // If there are no available chunks for allocation.
    // User should check the return value of this function for this case.
    resultis nil }

// Place the newly freed node at the front of the linked list of nodes, i.e.
// reassign `headptr`.
// Coalesce with neighboring chunks if those are free.
let firstfit_freevec(addr) be {
    let lchunk, rchunk;
    // Include the header data
    addr -:= node_metadata_left;

    // Free the chunk and add to the front of the freelist
    headptr := create(addr, size(addr), headptr, nil);

    // Now, check the chunks of memory to the right and to the left of
    // the chunk, not in the freelist but by address.
    // If those are free, then combine either or both with the newly freed
    // chunk to combat fragmentation.
    if ((addr - node_size) >= hstart) /\ (not inuse(addr ! -node_size)) then {
        lchunk := addr - (addr ! -1);
        addr := coalesce(lchunk, addr);
    }

    rchunk := addr + size(addr);
    if (rchunk < (hstart + hsize)) /\ (not inuse(size(rchunk))) then {
        addr := coalesce(addr, rchunk);
    }

    // Add again to headptr if we've coalesced since the last
    // reassignment of headptr
    headptr := addr;

    return }

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Memory Diagram ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// 0                                                                    [0x100]
//-----------------------------------------------------------------------------
// |||||||||||||||&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&|&|&|&|&|&|&|&|||||||||||||
//     [0x101]---^          free space              [future stack]    stack
// So, free space = heap space = 0x100 - (0x101 + anticipated total stack size)
// We return the lowest address of free space ([0x101]) & set hsize.
let probe() be {
    let result = 0, new_size;
    assembly {
        load  r1, [0x101]
        store r1, [<result>]
        load  r2, [0x100]
        sub   r2, r1
        store r2, [<new_size>] }
    // Reduce anticipated newsize by a semi-arbitrary amount.
    // Assume hstart hasn't yet been changed from it's initial value.
    new_size -:= hstart;
    // Make sure new_size is divisible by our chunk size before setting.
    // sample new_size values: f(14) = 0; f(17) = 16
    hsize := (new_size / node_min_size) * node_min_size;
    resultis result }

let init_heap() be {
    // Override the static declarations of newvec and freevec
    newvec := firstfit_newvec;
    freevec := firstfit_freevec;
    hstart := probe();
    // Setup the initial bigass node
    headptr := create(hstart, hsize, nil, nil);
    return }


let start() be {
    let a, b;
    init_heap();

    a := newvec(10);
    test a = nil then {
        out("a is nil\n");
    } else {
        out("freeing a...\n");
        freevec(a);
    }
    out("\n");

    b := newvec(60);
    test b = nil then {
        out("b is nil\n");
    } else {
        out("freeing b...\n");
        freevec(b);
    }

    return }
