# Assignment 5: A Design for a Full File System

# Overview

The file system described borrows heavily from the design of the Unix File System (UFS).
It has been pared down to use simpler data structures, e.g. bitmaps versus linked lists in consideration of a BCPL implementation and existence within an emulator.
<!-- For instance, like UFS we'll create a Multilevel Indexed File System with inodes.
But we'll stick to just single indirect blocks rather than double and triple since those are inductively easy to add-on in the future. -->

There are three main types of items on the disk, each grouped together and listed in ascending address on disk:

    ------------------------------
    | Superblock | inodes | Data |
    ------------------------------

We'll ignore the boot block and all of those out-of-scope details for this assignment.
Because of the small size of the disk, we'll omit indirect data chunks since the larger sizes they offer aren't possible to be taken advantage of with such a limited number of data chunks.
We'll start with a bottom-up design approach since many details are dependent on how many of a certain type of disk item/what size they are.


## Data Chunks

*Normal data chunk*: just 0.5K data, nonsense without inode details.
Data chunks are `0.5K = 512 bytes = 128 words` in size/alignment.

    -------------------------------------------
    | Chunk n-1   | Chunk n     | Chunk n+1   |
    | 128 words   | 128 words   | 128 words   |
    -------------------------------------------

<!-- *Indirect data chunk*: 128 1-word pointers to normal chunks (128K of addtl. data chunks)

    -----------------------------------------------------
    | Chunk n                                            |
    |      p1                p2         ...     p128     |
    ------------------------------------------------------
           |                 |                    |
           v                 v                    v
    ------------------------------------------------------
    | Chunk x     |     | Chunk y     |     | Chunk z    |
    | 128 words   | ... | 128 words   | ... | 128 words  |
    ------------------------------------------------------


Indirect data chunks need to reference data chunks somehow, which means that we'll have a predetermined indexing of data chunks determined at file system creation time.
We'll keep track of which chunks are occupied with a bitmap stored in the Superblock.
 -->

## inodes

    ----------------------------------------------
    | Permissions / File Size | 10 * Chunk Ptrs. |
    | (1 word)                | (10 words)       |
    ----------------------------------------------

<!-- ---------------------------
 1 * Indirect Chunk Ptrs. |
 (1 words)                |
--------------------------- -->

The star of the show, inodes, are also indexed and marked as free by a bitmap in the Superblock.
At their most basic, they are indexed (which gives an inode number) and have a mapping of a fixed number of data chunks.
They can also contain {created, modified, accessed} times, permissions, file sizes, and other protection metadata.
We'll use a system that gives us three fields comprised of 6 bits for permissions (r/w/x for user/others), 32 - 6 = 26 bits for size, and a 10/1 split of direct data chunks and singly indirect data chunks.
Thus, we use 1 + 10 = 11 words of disk space for each inode.

This inode design **does not allow for large files**.
In fact, if we assume that each inode represents one file, the maximum file size is 5K, which is small peanuts in reality, but with the emulated system we have, this maximum file size is acceptable-ish.

## Superblock

We'll use the term Superblock to refer to any elements of metadata about the disk that we keep at the front of the allocated space.
Thus, out Superblock will at least contain two bitmaps for data chunks and inode chunks.
In addition, we'll hold onto the used space, i.e. the number of free data chunks.

So now, we have a problem of how much space to use for our bitmaps while maximizing the number of usable data chunks.
Let's say we want to support up to 128 files.
Then we'll need 128 bits = 4 words of space for the inode bitmap.
1 word will be used to hold the number of free chunks.
Those 128 inodes will occupy 1408 words of space.

So, there are 6000 - (4 + 1 + 1408) = 4587 words left for the data chunks and data bitmap.
We'll use 4448 words for data.
Then, we'll have 139 words for the chunk bitmap.
We'll assume the bitmap is stored and searched on linearly for space efficiency.

## All Together

We can store up to 128 files, with a max file size of 5K and a maximum data volume of (4448 words * 32 bits/word) / 8192 bits/K = 17.4 K.

    Free Chunks (1) + inode Bitmap (4) + Data Bitmap (139) + inodes (1408) + Data Chunks (4448) = 6000 words

Thus, we assume that files do not get close to the max size.


# Directory Layout

So far, it's only been a mostly platform-agnostic overview of how we look at storage.
However, to be of any use, we need a way to access files.
We'll again use the Unix approach of hierarchical directory/files.
We'll store information about this structure as regular data, accessible and maintained by the operating system.
Each file will have its path stored as a two-tuple of (human readable name, inode index) in this directory file which will use 16 words per filename, which implies file paths cannot be longer than 16 * 4 = 64 characters (we'll have null-termination if enough space, otherwise we will use all space).
