#!/bin/bash

FROM=gif
TO=png
CRUSHED=opt.png
IMGPATH=$1
IMGPATH=${IMGPATH:=.}
PNG24='rgba'
PNG8='rgb'
current=1

# get the OS type, we need it later for branching
OS=`uname`
# by default use Unix/Mac 'stat' command
STATS_CMD="stat -f%z "

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
    local colorType=`file $file | awk '{print $9}' | tr '[A-Z]' '[a-z]' | tr -d ','`;
    #if [ $colorType == $PNG24 ] # This is a png24, do dirty transparency filtering ( note this is destructive technically, but not noticeable unless someone removed the image mask. )
    #then
    #    dirty_transparency $file
    #fi
    optipng -o7 -q $file;
    advpng -z -4 -q $file;
    pngout -q $file;
}

dirty_transparency() {
    local file=$1
    local mask=$file.mask.png
    local fixedTransparency=$1.fixed.png
    
    # convert mask2.png -white-threshold 0% mask21.png - Takes the mask and converts anything not black to white.
    # convert mask21.png -matte -fill none -draw 'color 255,255 replace' mask21none.png - Takes the black and white version and removes the white, leaving only the black overlay
    # convert zoom2.png mask21none.png -flatten zoom2test.png - Takes new layer ( black exclusion one from mask ) and puts it on top of original, then flattens ( Broken, this doesn't work properly )
    
    
    # Time for the dirty compression support.
    # 1. Extract alpha mask of image
    # 2. Combine the alpha mask to the image contents
    # 3. Flatten the new image ( mask + image )
    # 4. Apply the original mask onto the new image ( now masked areas dont have any image data but a solid background )
    
    # convert butterfly2.png -alpha extract mask.png
    # convert mask.png -combine butterfly2.png -flatten test.png
    # composite -compose Dst_In -gravity center butterfly2.png test.png -matte butterfly2.png
    
    convert $file -alpha extract $mask
    convert $mask -channel RGB -combine $file -flatten $fixedTransparency
    composite -compose Dst_In -gravity center $file $fixedTransparency -matte $file
    rm $mask
    rm $fixedTransparency
}

shrink() {
    local file=$1
    printf "%q/%q: %q" $current $count $file 
    FILETYPE=`file $file | awk '{print $2}' | tr '[A-Z]' '[a-z]'`;
        if [ $FILETYPE == $FROM ] #input is a gif
        then
            local start_size=$($STATS_CMD $file)
            local is_animated_gif=`gifsicle -I $file | grep -c 'loop'`; # Need to determine if this is an animated gif.
            if [ $is_animated_gif -eq 1 ]
            then
                # Is animated gif
                shrink_gif $file;
                local end_size=$($STATS_CMD $file)
                report $file $(($start_size - $end_size))
            else 
                # Isn't animated gif
                # step 1, optimize the gif
                shrink_gif $file;
                # step 2, get size of optimied gif as a reference.
                local gif_size=$($STATS_CMD $file)
                # step 3, convert the gif to png8 and optimize it.
                local png_file=${file%%$FROM}$TO
                pngout -q $file;
                shrink_png $png_file;
                local end_size=$($STATS_CMD $png_file)
                if [ $gif_size -gt $end_size ] # PNG is smaller, use png not gif
                then
                    rm $file;
                    report $png_file $(($start_size - $end_size))
                else # GIF is smaller, so delete the generated png
                    rm $png_file
                    report $file 0
                fi
            fi
        elif [ $FILETYPE == 'jpeg' ] # input is a jpeg
        then
            local start_size=$($STATS_CMD $file)
            shrink_jpeg $file;
            local jpeg_size=$($STATS_CMD $file)
            pngout -q $file;
            shrink_png $png_file;
            local end_size=$($STATS_CMD $png_file)
            if [ $jpeg_size -gt $end_size ]
            then
                rm $file;
                report $png_file $(($start_size - $end_size))
            else
                rm $png_file
                report $file $(($start_size - $jpeg_size))
            fi
        elif [ $FILETYPE == $TO ] #input is a png
        then
            local start_size=$($STATS_CMD $file)
            shrink_png $file;
            local end_size=$($STATS_CMD $file)
            report $file $(($start_size - $end_size))
        fi
    let current=current+1
}

# toggle to proper stat command depending on OS.
# in Linux(Ubuntu) the 'stat' command used in the code
# slightly differs from Mac/Unix for example: %z will 
# return the timestamp where as "-c" is used to specify 
# the FORMAT sequence, but in Mac it's "-f"
if [ $OS == 'Linux' ]; then
    STATS_CMD="stat -c %s "
fi

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