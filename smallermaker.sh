#!/bin/bash

FROM=gif
TO=png
CRUSHED=opt.png
IMGPATH=$1
IMGPATH=${IMGPATH:=.}
files=$(find $IMGPATH -regex ".*.[png|gif|jpg]") 
count=$(find $IMGPATH -regex ".*.[png|gif|jpg]" | wc -l)
current=1

echo $count "total files to process."
printf "#/#: orginal file : new file : space saved\n"

#"stat -f%z bob.txt" will return just the file size in bytes

for file in $files;do
    printf "%q/%q: %q" $current $count $file 
    FILETYPE=`file $file | awk '{print $2}' | tr '[A-Z]' '[a-z]'`;
        if [ $FILETYPE == $FROM ] #input is a gif
        then
            PNGFILE=`echo $file | sed "s/$FROM/$TO/g"`;
            PNGCRUSHED=`echo $file | sed "s/$FROM/$CRUSHED/g"`;
            pngout -q $file;
            pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -q -e .$CRUSHED $PNGFILE;
            rm $PNGFILE;
            optipng -o7 -q $PNGCRUSHED;
            advpng -z -4 -q $PNGCRUSHED;
            pngout -q $PNGCRUSHED;
            mv $PNGCRUSHED $PNGFILE;
            let spaceSaved=`ls -l $PNGFILE | awk '{print $5}'`-`ls -l $file | awk '{print $5}'`
            if [ `ls -l $file | awk '{print $5}'` -gt `ls -l $PNGFILE | awk '{print $5}'` ] # PNG is smaller, use png not gif
            then
                rm $file;
                printf " : %q : %q bytes\n" $PNGFILE $spaceSaved
            else # GIF is smaller, so delete the generated png
                rm $PNGFILE
                printf " : %q : 0 bytes\n" $file
            fi
        elif [ $FILETYPE == $TO ] #input is a png
        then
            originalSize=`ls -l $file | awk '{print $5}'`
            PNGFILE=`echo $file`;
            PNGCRUSHED=`echo $file | sed "s/$TO/$CRUSHED/g"`;
            pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -q -e .$CRUSHED $PNGFILE;
            rm $PNGFILE;
            optipng -o7 -q $PNGCRUSHED;
            advpng -z -4 -q $PNGCRUSHED;
            pngout -q $PNGCRUSHED;
            mv $PNGCRUSHED $PNGFILE;
            let spaceSaved=`ls -l $PNGFILE | awk '{print $5}'`-originalSize
            printf " : %q : %q bytes\n" $PNGFILE $spaceSaved
        fi
    let current=current+1
done