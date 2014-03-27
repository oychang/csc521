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
let size(addr, size) be {
    if numbargs() = 2 then {
        addr ! 1 := size;
        addr ! (size - 1) := size;
        return;
    }
    resultis (addr ! 1) }
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
let inuse(size_field) be {
    let lsb = size_field bitand 1;
    if lsb = 1 then out("chunk in use\n"); // xxx: log
    resultis lsb = 1 }
// Assume sizea <= sizeb
// Assume b is about to be used, so we don't need it to have pointers
let splitnode(baseaddr, sizea, sizeb) be
{   let blocka, blockb, prev, next;
    blocka := baseaddr;
    blockb := baseaddr + sizea;
    next := next(baseaddr);
    prev := prev(baseaddr);

    create(blocka, sizea, next, prev);
    create(blockb, sizeb, nil, nil);

    resultis blockb }
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


let firstfit_newvec(n) be
{   let node = headptr;
    let nodesize;
    let rchunksize;
    let realn = n + 4;
    let splitsize;

    // Use a first-fit strategy to get the first chunk with size >= n
    while node /= nil do {
        nodesize := size(node);

        // Check in use and proper size
        if (inuse(nodesize)) \/ (nodesize < realn) then {
            node := next(node);
            loop;
        }

        // If good, check if worthwhile to split
        // Every block is a multiple of 16.
        // Thus, only split this block into two separate ones
        // if, at a minimum, we can create another 16 block.
        if nodesize >= (realn + 16) then {
            rchunksize := splitsize << 4; // n * 16
            // for x positive, floor(n / 16) <=> (n-1)/16 + 1
            splitsize := ((realn - 1)/16) + 1;
            node := splitnode(node, rchunksize, nodesize - rchunksize);
            nodesize := rchunksize;
        }

        // Check if we need to reposition `headptr`, which happens in the case
        // when we are returning the memory chunk referred to by the current
        // head pointer. Pass the buck to the next one after that (which
        // might be nil).
        if node = headptr then {
            headptr := headptr ! 0;
        }

        // Set the node to used (set to an odd number)
        size(node) := nodesize + 1;

        // Return pointer to user's data area.
        resultis (node + 2);
    }

    resultis nil }


// Place the newly freed node at the front of the linked list of nodes, i.e.
// reassign `headptr`.
// Coalesce with neighboring chunks if those are free.
let firstfit_freevec(addr) be
{   let leftchunk, rightchunk;
    addr -:= 2; // Include the header

    // Check/coalesce left neighbor
    leftchunk := addr - (addr ! -1);
    out("chunk to the left starts at %d, has size %d\n", leftchunk, leftchunk ! 1);
    if (leftchunk /= 0) /\ (inuse(leftchunk ! 1) = 0) /\ (leftchunk >= hstart) then {
        out("about to coalesce with left chunk\n");
        addr := coalesce(leftchunk, addr);
    }

    // Check/coalesce right neighbor
    rightchunk := addr + (addr ! 1);
    out("chunk to the right starts at %d, has size %d\n", rightchunk, rightchunk ! 1);
    if (rightchunk /= 0) /\ (inuse(rightchunk ! 1) = 0) /\ (rightchunk < (hstart + hsize)) then {
        out("about to coalesce with right chunk\n");
        addr := coalesce(addr, rightchunk);
    }

    // Add to headptr
    headptr := create(addr, addr ! 1, headptr, nil);

    return }


// Let the memory address that marks the beginning of heap memory
// be 1024 words away from our OS stuff (this program).
// Assume that this is far away and do not do the entire probe process.
// Ensure this is at the end of the program so that its address
// will be far away from stuff in use.
let probe() be
{ }
let init_heap() be
{   // Override the static declarations of newvec and freevec
    newvec := firstfit_newvec;
    freevec := firstfit_freevec;
    hstart +:= probe;
    headptr := hstart;
    // Setup the initial bigass node
    create(hstart, hsize, nil, nil);
    return }


let start() be
{   let a, b;
    init_heap();

    // Test instructions
    a := newvec(10);
    test a = nil then {
        out("a is nil\n");
    } else {
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
