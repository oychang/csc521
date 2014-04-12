import "io"

// These form the pseudo-struct offsets and values that allow us to easily
// talk about nodes.
manifest {
    node_key = 0,
    node_left = 1,
    node_right = 2,
    sizeof_node = 3,
    heap_size = 10000
}

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
    // Setup which direction we're going by changing which field of the node
    // we look at to get the next one.
    let offset = reversed -> node_left, node_right;

    out("X<-->");
    while node /= nil do {
        out("[%d]<-->", node ! node_key);
        node := node ! offset;
    }
    out("X\n");

    return }

// NB: the default implementation of freevec() calls lamest_freevec() which
// is an empty function, i.e. freeing does not do anything by default
let free_list(head) be {
    let node = head;
    let tmp;
    while node /= nil do {
        tmp := node;
        node := node ! node_right;
        freevec(tmp);
    }

    return }


let start() be {
    let head = nil, tail = nil, input = -1, SENTINEL = -1;
    let new_node = nil;
    let heap = vec(heap_size);
    init(heap, heap_size);

    out("add numbers to doubly linked list\n");
    out("insert ");
    input := inno();
    while input /= SENTINEL do {
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
        input := inno();
    }

    // Print the lists
    out("linked list (forward)\n");
    pprint_list(head, false);

    out("linked list (backward)\n");
    pprint_list(tail, true);

    // Free the allocated nodes
    free_list(head);

    out("done\n") }
