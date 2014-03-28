import "io"

// Much lecture notes. Such helpful. Wow.
// http://www.cs.princeton.edu/courses/archive/spr11/cos217/lectures/20DynamicMemory2.pdf
// ~~~~~~~~~~~~~~~~~~~~~~~ Anatomy of a Chunk of Memory ~~~~~~~~~~~~~~~~~~~~~~~
//    |======================================================================|
//    |             Header            | Data |             Footer            |
//    |-------------------------------|------|-------------------------------|
//    | FreePtr (Next) | Size / InUse | .... | FreePtr (Prev) | Size / InUse |
//    |======================================================================|
// Let the minimum amount of allocatable memory be 16 blocks
// Let each chunk of memory be divisible by 16, e.g. 16, 32, 48, 64, ...
// Let each chunk of memory be node a in a doubly linked list
// Let each node have a header and a footer
// Let the header be two words: a pointer to the next free & real size of block
// Let the footer be two words: a poitner the the previous free & real size
// Usable size of the chunk = real size - 4
// All chunks will have an even size => last bit of size used for in-use flag

manifest { hsize = 64 }
static { hstart = 1024, headptr }


let size(addr, n) be {
    // Setter. Assume that address is a valid chunk header and that we can
    // access up to addr + n - 1 words of memory to set the footer size.
    if numbargs() = 2 then {
        addr ! 1 := n;
        addr ! (n - 1) := n;
        return;
    }

    // Getter. Assume address is a valid chunk and that header == footer size.
    // Assume that we will only have even sizes...the least significant bit
    // is used for status. Thus, most sizes will be literally represented as
    // off-by-one. The mask compensates for that.
    resultis ((addr ! 1) bitand 0xfffffffe) }

let next(addr, nextaddr) be {
    // Setter. Assume addr is a valid chunk. nextaddr might be a valid
    // memory address for the header of a free chunk, in which case
    // we set that chunk's previous field, or nil, in which case we just stop
    // after setting this chunk's next field.
    if numbargs() = 2 then {
        addr ! 0 := nextaddr;
        if nextaddr /= nil then
            nextaddr ! (size(nextaddr) - 2) := addr;
        return;
    }

    // Getter. Do not assume that addr is valid (useful for chaining).
    if addr /= nil then
        resultis (addr ! 0);
    resultis nil }

let prev(addr, prevaddr) be {
    let n;
    // Setter. Since the previous field is in the footer, we assume that
    // this chunk is valid and its size field has been set so we can get
    // to the previous field, the penultimate word of the chunk.
    // Behave identically to next() w.r.t. nil 2nd argument.
    if numbargs() = 2 then {
        n := size(addr);
        addr ! (n - 2) := prevaddr;
        if prevaddr /= nil then
            prevaddr ! 0 := addr;
        return;
    }

    // Getter. Check for nillness (like next()) for chaining reasons.
    if addr /= nil then {
        n := size(addr);
        resultis (addr ! (n - 2));
    }
    resultis nil }

let create(addr, chunksize, nextaddr, prevaddr) be {
    size(addr, chunksize);
    prev(addr, prevaddr);
    next(addr, nextaddr);
    resultis addr }

// Get the least significant bit of a 32-bit word and compare to 1.
// If 1, then this node is in use. Otherwise, we're freee
let inuse(n) be {
    let lsb = n bitand 1;
    resultis lsb = 1 }

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
    if (lprev /= nil) /\ (next(rchunk) /= nil) then {
        prev(next(rchunk), lprev);
    }
    // d) rightchunk's next's previous becomes leftchunk's previous's next
    rnext := prev(next(rchunk));
    if (rnext /= nil) /\ (prev(lchunk) /= nil) then {
        next(prev(lchunk), rnext);
    }

    resultis create(lchunk, totalsize, newnext, newprev) }


let firstfit_newvec(n) be {
    let chunk = headptr; // Where to start search for available chunks.

    let chunks; // Current search chunk size
    let reals = n + 4; // 2 word header, footer
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
        if chunks >= (reals + 16) then {
            // For x positive, ceil(n / 16) <=> (n-1)/16 + 1
            rchunks := (((reals - 1) >> 4) + 1) << 4;
            lchunks := chunks - rchunks;
            chunk := split(chunk, lchunks, rchunks);
            chunks := rchunks;
        }

        // Check if we need to reposition `headptr`, which happens in the case
        // when we are returning the memory chunk referred to by the current
        // head pointer. Pass the buck to the next one after that (which
        // might be nil).
        if chunk = headptr then {
            headptr := next(headptr);
        }

        // Set the node to used (set to an odd number)
        size(chunk, chunks + 1);
        // Return pointer to user's data area.
        resultis (chunk + 2);
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
    addr -:= 2;

    // Free the chunk and add to the front of the freelist
    headptr := create(addr, size(addr), headptr, nil);

    // Now, check the chunks of memory to the right and to the left of the chunk,
    // not in the freelist but by address.
    // If those are free, then combine either or both with the newly freed
    // chunk to combat fragmentation.
    if ((addr - 1) >= hstart) /\ (inuse(addr ! -1) = 0) then {
        lchunk := addr - (addr ! -1);
        out("chunk to the left starts at %d, has size %d\n", lchunk, size(lchunk));
        out("about to coalesce with left chunk\n");
        addr := coalesce(lchunk, addr);
    }

    rchunk := addr + size(addr);
    if (rchunk < (hstart + hsize)) /\ (inuse(size(rchunk)) = 0)  then {
        out("chunk to the right starts at %d, has size %d\n", rchunk, size(addr));
        out("about to coalesce with right chunk\n");
        addr := coalesce(addr, rchunk);
    }

    // Add again to headptr if we've coalesced since the last
    // reassignment of headptr
    headptr := addr;

    return }


// Let the memory address that marks the beginning of heap memory
// be 1024 words away from our OS stuff (this program).
// Assume that this is far away and do not do the entire probe process.
// Ensure this is at the end of the program so that its address
// will be far away from stuff in use.
let probe() be
{ }
let init_heap() be {
    // Override the static declarations of newvec and freevec
    newvec := firstfit_newvec;
    freevec := firstfit_freevec;
    // Setup the initial bigass node
    hstart +:= probe;
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

//    b := newvec(60);
//    test b = nil then {
//        out("b is nil\n");
//    } else {
//        freevec(b);
//    }

    return }
