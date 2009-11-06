#!/bin/sh

# Usage gs FILE PAGE

gs \
    -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r96 \
    -dTextAlphaBits=4 -dGraphicsAlphaBits=4 \
    -dFirstPage=$2 -dLastPage=$2 \
    -sOutputFile=- $1
