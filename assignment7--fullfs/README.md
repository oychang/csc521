# Style
* Manifest constants are in screaming snake case
* Try to namespace constants as much as possible
* Take advantage of optional braces for one line functions
* Use snake case for variable names
* Favor automatic, stack vecs over newvec/freevec
* Compose small, simple functions into larger, more complex ones whenever
possible
* Pass anything that might change as a parameter
* Try to steer towards pure, non-side effect functions as much as possible
* Liberally export, but pay attention to namespacing conflicts
* Add non-library bcpl files to the `.make` file to easily compile
* Make targets: `make` and `make clean` and `make clean-submit` (removes exes)
* Wherever possible, use names for numeric constants
* Error check functions return codes with the pseudo-enums defined above them


# Provided Utilities
* cd (with relative pathnames)
* ls & tree
* pwd
* stat
* touch
* mkdir
* cat
* simple pico

# Superblock
* First block on disc
* Contains meta information about disc

## Format
* Unique number that identifies disc as formatted, e.g. 0x1234
* Size of filesystem in blocks, e.g. 6000
* Number of used blocks
* Location of root directory
* Datetime created
* Free [Bitmap (??)] of free indoes, data blocks

# inode

## Format
* create time, last modified time
* directory or file flag
* size
* data -- either location of data or directory entries

## Root directory
* Contains two special directories, `/tape` and `/dev` from which commands like `mount /tape/1 unixfile.txt` and `cat /dev/stdout` are possible. Ensure these cannot be overwritten.

# Data block
* Just contains a bunch of raw data