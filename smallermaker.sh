#!/bin/bash

FROM=gif
TO=png
CRUSHED=opt.png
IMGPATH=$1
IMGPATH=${IMGPATH:=.}
current=1

header() {
    echo "#/#: orginal file : new file : space saved\n"
    echo $count "total files to process."
}

report() {
    printf " : %q : %q bytes\n" $1 $2
}

shrink_jpeg() {
    local file=$1
    jpegtran -copy none -trim -optimize -outfile $file.jpg $file;
    mv $file.jpg $file
    wrjpgcom -replace -comment "" $file
    jpegoptim -q $file
}

shrink_gif() {
    local file=$1
    gifsicle --batch -O2 $file;
}

shrink_png() {
    local file=$1
    PNGFILE=$file
    PNGCRUSHED=${file%%$TO}$CRUSHED
    pngcrush -rem gAMA -rem cHRM -rem iCCP -rem sRGB -brute -q -e .$CRUSHED $PNGFILE;
    rm $PNGFILE;
    optipng -o7 -q $PNGCRUSHED;
    advpng -z -4 -q $PNGCRUSHED;
    pngout -q $PNGCRUSHED;
    mv $PNGCRUSHED $PNGFILE;
}
shrink() {
    local file=$1
    printf "%q/%q: %q" $current $count $file 
    FILETYPE=`file $file | awk '{print $2}' | tr '[A-Z]' '[a-z]'`;
        if [ $FILETYPE == $FROM ] #input is a gif
        then
            local start_size=$(stat -f%z $file)
            local is_animated_gif=`gifsicle -I $file | grep -c 'loop'`; # Need to determine if this is an animated gif.
            if [ $is_animated_gif -eq 1 ]
            then
                # Is animated gif
                shrink_gif $file;
                local end_size=$(stat -f%z $file)
                report $file $(($start_size - $end_size))
            else 
                # Isn't animated gif
                # step 1, optimize the gif
                shrink_gif $file;
                # step 2, get size of optimied gif as a reference.
                local gif_size=$(stat -f%z $file)
                # step 3, convert the gif to png8 and optimize it.
                local png_file=${file%%$FROM}$TO
                pngout -q $file;
                shrink_png $png_file;
                local end_size=$(stat -f%z $png_file)
                if [ $gif_size -gt $end_size ] # PNG is smaller, use png not gif
                then
                    rm $file;
                    report $PNGFILE $(($start_size - $end_size))
                else # GIF is smaller, so delete the generated png
                    rm $png_file
                    report $file 0
                fi
            fi
        elif [ $FILETYPE == 'jpeg' ] # input is a jpeg
        then
            local start_size=$(stat -f%z $file)
            shrink_jpeg $file;
            local end_size=$(stat -f%z $file)
            report $file $(($start_size - $end_size))
        elif [ $FILETYPE == $TO ] #input is a png
        then
            local start_size=$(stat -f%z $file)
            shrink_png $file;
            local end_size=$(stat -f%z $file)
            report $PNGFILE $(($start_size - $end_size))
        fi
    let current=current+1
}

if [ -f $IMGPATH ]; then
    count=1
    header
    shrink $IMGPATH
else
    files=$(find $IMGPATH -regex ".*.[jpg|png|gif]") 
    count=$(find $IMGPATH -regex ".*.[jpg|png|gif]" | wc -l)
    header
    for file in $files; do
        shrink $file
    done
fi