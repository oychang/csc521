# Provided Utilities
* cd (with relative pathnames)
* ls & tree
* pwd
* stat
* touch
* mkdir
* cat
* simple editor

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