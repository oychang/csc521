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

let splitnode() be
{
}

let createnode(addr, size, nextptr, prevptr) be
{   addr ! 0 := nextptr;
    addr ! 1 := size;
    addr ! (size - 2) := prevptr;
    addr ! (size - 1) := size;

    resultis addr }

// Let the memory address that marks the beginning of heap memory
// be 1024 words away from our OS stuff (this program).
// Assume that this is far away and do not do the entire probe process.
// Ensure this is at the end of the program so that its address
// will be far away from stuff in use.
let probe() be
{ }


let firstfit_newvec(n) be
{   let node = headptr;
    let realn = n + 4;

    // Use a first-fit strategy to get the first chunk with size >= n
    while node /= nil do {
        // Check in use
        if inuse(node ! 1) then {
            node := node ! 0;
            loop;
        }

        // Check size
        if (node ! 1) < realn then {
            node := node ! 0;
            loop; // <=> continue
        }

        // If good, check if worthwhile to split
//        if (node ! 1) > (realn + 16) then {
//
//        }

        // Set the node to used (set to an odd number)
        node ! 1 := (node ! 1) + 1;

    }

    resultis nil }


let firstfit_freevec(addr) be
{
    return }


let start() be
{   let a;
    // Override the static declarations of newvec and freevec
    newvec := firstfit_newvec;
    freevec := firstfit_freevec;
    hstart +:= probe;
    // Setup the initial bigass node
    headptr := createnode(hstart, hsize, nil, nil);

    // Test instructions
    a := newvec(10);
    freevec(a);

    return }
