#! /bin/sh

# Update all files from a new run after encoding code has
# changed. Use case: You changed the character encoding from
# latin1 to UTF-8. Now all the test files are wrong. Run the
# tests once to produce the new outputs, then use this to
# upadte all the test files at once.

# You still need to go through the outputs and make sure
# it's only the encodings that change!

cp tmp/out.201 .
cp tmp/out.200 .
cp tmp/out.15 .
cp tmp/out.15b .
cp tmp/out.15c .
cp tmp/out.2 .

cp tmp/out.20 .

cp tmp/out.30 .

cp tmp/out.1 .
cp tmp/out.1c .
cp tmp/out.1d .
cp tmp/out.1e .

cp tmp/out.71 .

