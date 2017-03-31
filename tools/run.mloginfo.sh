#!/bin/sh

# brew install gnu-sed
LOG_FOLDER=$1
MLOGINFO_FOLDER=$LOG_FOLDER/output/mloginfo
TSV_FOLDER=$LOG_FOLDER/output/tsv

for d in $LOG_FOLDER/*.log ; do
    echo "Please wait. Processing mloginfo on '$d'"
    mloginfo --no-progressbar --queries --sort count "$d" > "$d.mloginfo" 
    cat "$d.mloginfo" | 
        gsed 's/[ ]\+version\: =/version\t/g' | \
        gsed 's/date format: /dateformat\t/g' | \
        sed 's/: /:/g' | sed 's/, /,/g' | \
        gsed 's/^[ ]\+\([[:alpha:]]\+\):/\1\t/g' | \
        gsed 's/[[:space:]]\{2,\}/\t/g' > "$d.tsv"
    echo "Completed generating tsv file for '$d'"
done

# create mloginfo folder and move mloginfo files there 
mkdir -p $MLOGINFO_FOLDER
mv *.mloginfo $MLOGINFO_FOLDER/

# create tsv folder and move tsv files there
mkdir -p $TSV_FOLDER
mv *.tsv $TSV_FOLDER/

echo "Completed processing all files in '$d'"