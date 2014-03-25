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
// NB: ternary if := A -> B, C

manifest { hsize = 128 }
static { hstart = 1024, headptr }

// Get the least significant bit of a 32-bit word and compare to 1.
// If 1, then this node is in use. Otherwise, we're freee
let inuse(size_field) be
{   let tmp = size_field bitand 0x1;
    resultis tmp = 1 }

let splitnode(baseaddr, sizea, sizeb) be
{ out("%d %d\n", sizea, sizeb);
    return }

let createnode(addr, size, nextptr, prevptr) be
{   addr ! 0 := nextptr;
    addr ! 1 := size;
    addr ! (size - 2) := prevptr;
    addr ! (size - 1) := size;

    resultis addr }


let firstfit_newvec(n) be
{   let node = headptr;
    let nodesize;
    let realn = n + 4;
    let splitsize;

    out("looking for a chunk of size %d (to allocate %d)\n", realn, n);
    // Use a first-fit strategy to get the first chunk with size >= n
    while node /= nil do {
        nodesize := node ! 1;

        // Check in use and proper size
        if (inuse(nodesize)) \/ (nodesize < realn) then {
            out("bad node\n");
            node := node ! 0;
            loop;
        }

        // If good, check if worthwhile to split
        // Every block is a multiple of 16.
        // Thus, only split this block into two separate ones
        // if, at a minimum, we can create another 16 block.
        if nodesize >= (realn + 16) then {
            // for x positive, floor(n / 16) <=> (n-1)/16 + 1
            splitsize := ((realn - 1)/16) + 1;
            node := splitnode(node, splitsize*16, nodesize - (splitsize*16));
            nodesize := splitsize * 16;
        }

        // Check if we need to reposition `headptr`
        if node = headptr then {
            headptr = node ! 0; // TODO: debug
        }

        // Set the node to used (set to an odd number)
        out("setting node to used\n");
        node ! 1 := nodesize + 1;

        // Return pointer to the
        resultis (node + 2);
    }

    resultis nil }


let firstfit_freevec(addr) be
{
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
    createnode(hstart, hsize, nil, nil);
    return }


let start() be
{   let a;
    init_heap();

    // Test instructions
    a := newvec(10);
    freevec(a);

    return }
