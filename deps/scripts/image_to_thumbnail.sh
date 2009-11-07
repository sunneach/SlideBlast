#!/bin/sh

# Usage:
# ./image_to_thumbnail.sh (Image) > thumbnail.png

convert $1 -thumbnail "80x60^" -gravity "center" -
