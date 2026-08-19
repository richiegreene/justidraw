#!/bin/sh
# repackages src/ into justidraw.love, the bundle Engrave's "Edit..." launches.
# run this after any change under src/ before testing through Engrave.
set -e
cd "$(dirname "$0")"
rm -f justidraw.love
cd src
zip -r -X ../justidraw.love . -x ".*"
