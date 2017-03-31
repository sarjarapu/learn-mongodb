#!/bin/sh

# brew install gnu-sed 
OUTPUT_FILES=$1

for d in $OUTPUT_FILES/*.log ; do
    echo "$d"
    cat "$d" | 
        gsed 's/[ ]\+version\: =/version\t/g' | \
        gsed 's/date format: /dateformat\t/g' | \
        sed 's/: /:/g' | sed 's/, /,/g' | \
        gsed 's/^[ ]\+\([[:alpha:]]\+\):/\1\t/g' | \
        gsed 's/[[:space:]]\{2,\}/\t/g' > "$d.tsv"
done

