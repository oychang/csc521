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

// ==== Chunk getter/setter functions
// -- Setting
// size(node) := 3;
// size(node, 3);
// -- Getting (assume node is address of header and is valid)
// out("%d\n", size(node))

// Assume that we will only have even sizes...the least significant bit
// is used for status. Thus, most sizes will be literally represented as
// off-by-one. The mask compensates for that.
let size(addr, size) be {
    if numbargs() = 2 then {
        addr ! 1 := size;
        addr ! (size - 1) := size;
        return;
    }
    resultis ((addr ! 1) bitand 0xfffffffe) }
let next(addr, nextaddr) be {
    if numbargs() = 2 then {
        addr ! 0 := nextaddr;
        return;
    }
    resultis (addr ! 0) }
// Assume size field has been set by this point
let prev(addr, prevaddr) be {
    let size = size(addr);
    if numbargs() = 2 then {
        addr ! (size - 2) := prevaddr;
        return;
    }
    resultis (addr ! (size - 2)) }
let create(addr, size, nextaddr, prevaddr) be {
    size(addr, size);
    prev(addr, prevaddr);
    next(addr, nextaddr);
    resultis addr }

// ==== Utility Functions
// Get the least significant bit of a 32-bit word and compare to 1.
// If 1, then this node is in use. Otherwise, we're freee
let inuse(size) be {
    let lsb = size bitand 1;
    if lsb = 1 then out("chunk in use\n"); // xxx: log
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

// TODO: completely borked
// Collapse down leftchunk and rightchunk into one chunk and return the
// address that points to the header section of the left, newly combined chunk.
let coalesce(leftchunk, rightchunk) be
{   let leftsize = (leftchunk ! 1) bitand 0xfffffffe;
    let rightsize = (rightchunk ! 1) bitand 0xfffffffe;
    let totalsize = leftsize + rightsize;

    // We have four node pointers to change:
    // a) leftchunk's next becomes newchunk's next
    let newnext = leftchunk ! 0;
    // b) rightchunk's previous becomes newchunk's previous
    let newprev = rightchunk ! (rightsize - 2);

    out("leftchunk @ %d, rightchunk @ %d\n", leftchunk, rightchunk);
    out("leftchunk is %d, rightchunk is %d\n", leftsize, rightsize);
    out("got totalsize as %d\n", totalsize);
    out("newnext = %d, newprev = %d\n", newnext, newprev);
    return }

    // c) leftchunk's previous's next becomes rightchunk's next's previous
    // d) rightchunk's next's previous becomes leftchunk's previous's next
    //let leftchunk_prev_next = nil, rightchunk_next_prev = nil;
    //let leftchunk_prev = leftchunk ! ((leftchunk ! 1) - 1);
    //let rightchunk_next = rightchunk ! 0;
    // Do this in case either of the above fields are set to nil.
    //if leftchunk_prev /= nil then {
    //    leftchunk_prev_next =
    //}
    //leftchunk_prev_next = leftchunk_prev ! 0;
    //rightchunk_next_prev = rightchunk_next ! ()

    //resultis create(leftchunk, totalsize, newnext, newprev) }


let firstfit_newvec(size) be {
    let chunk = headptr; // Where to start search for available chunks.

    let chunks; // Current search chunk size
    let reals = size + 4; // 2 word header, footer
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
            lchunks := ((reals - 1) >> 4) + 1;
            rchunks := nodes - lchunks;
            node := split(node, lchunks, rchunks);
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

    // Check/coalesce left neighbor
    lchunk := addr - (addr ! -1); // use back size word
    out("chunk to the left starts at %d, has size %d\n", lchunk, size(lchunk));
    if (lchunk /= 0)
        /\ (inuse(size(lchunk)) = 0)
        /\ (lchunk >= hstart) then {
        out("about to coalesce with left chunk\n");
        addr := coalesce(lchunk, addr);
    }

    // Check/coalesce right neighbor
    rchunk := addr + size(addr);
    out("chunk to the right starts at %d, has size %d\n", rchunk, size(addr));
    if (rightchunk /= 0)
        /\ (inuse(size(rchunk)) = 0)
        /\ (rchunk < (hstart + hsize)) then {
        out("about to coalesce with right chunk\n");
        addr := coalesce(addr, rchunk);
    }

    // Add to headptr
    headptr := create(addr, size(addr), headptr, nil);

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
    hstart +:= probe;
    headptr := hstart;
    // Setup the initial bigass node
    create(hstart, hsize, nil, nil);
    return }


let start() be {
    let a, b;
    init_heap();

    // Test instructions
    a := newvec(10);
    test a = nil then {
        out("a is nil\n");
    } else {
        out("free\n"); // xxx: log
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
