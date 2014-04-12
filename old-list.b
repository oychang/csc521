import "io"

// These form the pseudo-struct offsets that allow us to easily
// talk about nodes.
manifest {
    node_key = 0,
    node_left = 1,
    node_right = 2,
    sizeof_node = 3 }

// Allocate three words of contiguous memory on the heap and set the
// key field to the given value. Pass back the pointer to the node.
let create_node(key) be {
    let node = newvec(sizeof_node);
    node ! node_key := key;
    resultis node }

// Prints a representation of the doubly linked list of decimals.
// First arg: a valid node.
// Second arg: a boolean describing whether traversal should be reversed or not.
let pprint_list(start, reversed) be {
    let node = start;
    let next_node_offset = (test reversed then node_left else node_right);

    out("X<-->");
    while next_node /= nil do {
        out("[%d]<-->", node ! node_key);
        node := node ! next_node_offset; }
    out("X\n");

    return }

let free_list(head) be {
    let node = head;
    let tmp;
    while node /= nil do {
        tmp := node;
        node := node ! node_right;
        freevec(tmp); }

    return }


let start() be {
    let head = nil, tail = nil, input = -1, SENTINEL = -1;
    let new_node = nil;
    // The two numbers here should match up; they must be compile-time
    // constants though, so we do not use a variable.
    let heap = vec(10000);
    init(heap, 10000);

    out("add numbers to doubly linked list\n");
    out("insert ");
    input := inno();
    while input /= SENTINEL then {
        new_node := create_node(input);

        // Add node to list, with attention to initial case
        test head = nil then {
            head := new_node;
            tail := new_node;
        } else {
            tail ! node_right := new_node;
            new_node ! node_left := tail;
            tail := new_node;
        }
        out("insert ");
        input := inno(); }

    // Print the lists
    out("linked list (forward)\n");
    pprint_list(head, false);

    out("linked list (backward)\n");
    pprint_list(tail, true);

    // Free the allocated nodes
    free_list(head);

    out("done\n") }
