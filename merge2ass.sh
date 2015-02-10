#!/bin/bash
# merge2ass.sh - script for merging two text-subtitles into an ass subtitle file
# version 0.9, 8-august-2007
# comments/criticism/praise to jose1711-gmail-com

# dependencies: mplayer (if your subtitle files need to be converted to srt), gnu utils, bc

# thanks to:
#  - d.watzke for comments
#  - belisarivs for testing
#  - boris dušek <boris (dot) dusek - gmail - com> for testing/ideas
#
# $1 is a movie file
# $2 is a subtitle1
# $3 is a subtitle2
# $4 is optional and could be "-pm" or "--play-movie" for instant watching of the movie, or --srt for converting to .srt file instead of .ass
# $5 is optional and could be "-pm" or "--play-movie" for instant watching of the movie, or --srt for converting to .srt file instead of .ass
# 

# example:
# merge2ass.sh movie.avi english.srt slovak.sub
# mplayer -noautosub -ass movie.avi -sub movie-bilingual.ass -subcp utf8
#
# or just
# merge2ass.sh movie.avi english.srt slovak.sub -pm
#
# or even only
# merge2ass.sh --detect movie.avi -pm
#
# or 
# merge2ass.sh movie.avi english.srt slovak.sub --srt
#
# ;-)
#
# release history:
# 0.8a (29. 7. 2007)
#  - initial public release
# 0.8.1a (30. 7. 2007)
#  - check_syntax fixed (d.watzke)
#  - multiline echo -> cat (d.watzke)
#  - removes temp files after conversion
# 0.8.2 (1. 8. 2007)
#  - check whether the input files exist prior to running MPlayer
#  - check for MPlayer binary
#  - help page added
#  - new optional CLI parameters: -pm (plays movie after conversion), --help
# 0.8.2.1 (2. 8. 2007)
#  - timestamp in output more compatible (reported by belisarivs)
# 0.9 (8. 8. 2007)
#  - performs a check for writable output
#  - check for MPlayer's support of ass/ssa if -pm is used
#  - pointers to subtitle files stored as arrays
#  - autorecognition of subtitles based on MPlayer's -sub-fuzziness feature (--detect)
#  - output filename based on movie filename (+bilingual.ass)
#  - bash now mandatory (non-POSIX syntax used)
#  - flag -pm has a long alias (--play-movie)
# 0.9.1 (21. 01. 2013)
#  - adding srt support
 
# some future thoughts:
#   - more optional flags (do_not_remove_temp_files, play_but_dont_delete_output_afterwards,dont_do
#     the_conversion_just_merging,output_file..)
#   - cleaner sed/awk code
#   - support for other players (xine, totem, kmplayer, vlc..)
#   - subtitle encoding detection based on enca (if present) - boris?
#   - percentage for srt conversion
#
# docs:
#   - http://en.wikipedia.org/wiki/SubStation_Alpha
#   - http://www.perlfu.co.uk/projects/asa/ass-specs.doc
#
# THE STORY ENDS HERE
# set -x

# normally you do not want to see mplayer's error output
#mplayer_err=/dev/stderr
mplayer_err=/dev/null

arg_count="$#"
movie="$1"
sub[1]="$2"
sub[2]="$3"


show_help(){
cat <<EOF
 ----------------------------------------------------------------------------------
|                                                                                  |
|  Merge2ass - a script for merging two text subtitles into ass/ssa subtitle file  |
|                                         author: jose1711 - gmail - com, 2007/08  |
 ----------------------------------------------------------------------------------

  Usage: merge2ass.sh [--help] [movie subtitle1 subtitle2] [-pm|--play-movie][--srt]

         or

	 merge2ass.sh --detect movie [-pm|--play-movie]

--help        show this help page and exit

--detect      try to detect subtitles using MPlayer's sub-fuzziness=1 flag

movie         movie file (anything that MPlayer recognizes)
subtitle[12]  file(s) containing text subtitles that MPlayer recognizes 

-pm           play movie immediately and remove the output after finishing
--play-movie

--srt        convert into a .srt instead of a .ass, much slower.

EOF
}

detect_subtitles(){
	while read -r line; do
		sub[++i]="$line"
	done < <(mplayer -sub-fuzziness 1 -frames 0 "$movie" 2>/dev/null | sed -n "s/^SUB: Added subtitle file ([0-9]*): \(.*\)$/\1/p")
	echo "$i subtitles were detected in total."
	echo "These two will be used:"
	echo "${sub[1]}"
	echo "${sub[2]}"
}

convert_subs(){
type mplayer || { echo "MPlayer not installed or binary not in path, please investigate. Exiting.."; exit 1; } 

echo "Converting the 1st subtitle file (${sub[1]}) to a time-based format..."
# slower but does not require the video file for conversion
# mplayer /dev/zero -rawvideo pal:fps=25 -demuxer rawvideo -vc null -vo null -noframedrop -benchmark -sub "$movie" -dumpsrtsub
mplayer -utf8 -dumpsrtsub -noautosub -really-quiet -frames 0 -sub "${sub[1]}" "$movie" 2>>"$mplayer_err" && echo "Done"
mv dumpsub.srt "${sub[1]}-temp"
echo "Converting the 2nd subtitle file (${sub[2]}) to a time-based format..."
mplayer -utf8 -dumpsrtsub -noautosub -really-quiet -frames 0 -sub "${sub[2]}" "$movie" 2>>"$mplayer_err" && echo "Done"
mv dumpsub.srt "${sub[2]}-temp"
}

generate_ssa_header(){
cat > "$output" << EOF
[Script Info]
Title:
Original Script: 
Original Translation:
Original Editing: 
Original Timing: 
Original Script Checking:
ScriptType: v4.00
Collisions: Normal
PlayResY: 1024
PlayDepth: 0
Timer: 100,0000

[V4 Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding
Style: lang1style,Arial,64,65535,65535,65535,-2147483640,-1,0,1,3,0,6,30,30,30,0,0
Style: lang2style,Arial,64,15724527,15724527,15724527,4144959,0,0,1,1,2,2,5,5,30,0,0

[Events]
Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text 
EOF
}

generate_ssa_dialogs(){
sed -e "/ --> /s/,/./g" "${sub[1]}-temp" | tr -d "\r" | awk 'BEGIN{ORS="";print " "} / --> /,/^$/ {ORS=" ";print} /^$/{print "\n"}' | sed -e "s/ --> /,/g" -e "s/^ \([^ ]*\) \(.*\)/Dialogue: Marked=0,\1,lang1style,Cher,0000,0000,0000,,\2/" -e "s/,00:/,0:/g" -e "s/\([:,]\)0\([0-9]\)/\1\2/g"  >>$output
sed -e "/ --> /s/,/./g" "${sub[2]}-temp" | tr -d "\r" | awk 'BEGIN{ORS="";print " "} / --> /,/^$/ {ORS=" ";print} /^$/{print "\n"}' | sed -e "s/ --> /,/g" -e "s/^ \([^ ]*\) \(.*\)/Dialogue: Marked=0,\1,lang2style,Cher,0000,0000,0000,,\2/" -e "s/,00:/,0:/g" -e "s/^ *//g" -e "s/\([:,]\)0\([0-9]\)/\1\2/g" >>$output
}

remove_temp_files(){
rm "${sub[1]}-temp" "${sub[2]}-temp"
}

play_movie(){
	mplayer -ass 2>/dev/null >/dev/null || { echo "Too old MPlayer version, can't understand ASS/SSA subs. Install a newer version."; exit 1; }
    echo $output
	mplayer -really-quiet -fs "$movie" -sub "$output" -ass -subcp utf8 -noautosub
}

delete_output(){
	rm "$output"
}

next_sub1()
{
    line=""
    while [[ ! $line =~ $timePattern ]]; do
        if ! read -r line <&6; then
            eof1=1
            break
        fi
    done
    ftimeString=`echo $line|cut -d' ' -f 1`
    ltimeString=`echo $line|cut -d' ' -f 3`
    ftime=`echo $ftimeString |sed 's/,/./g' |awk -F: '{ printf( "%.3f \n",$1*3600 + $2*60 + $3) }'`
    ltime=`echo $ltimeString |sed 's/,/./g' |awk -F: '{ printf( "%.3f \n",$1*3600 + $2*60 + $3) }'`
    sub1=""
    while [[ ! -z $line ]]; do
        read -r line <&6
        if [[ ! -z $line ]]; then
            if [[ -z $sub1 ]]; then
                sub1=$line
            else
                sub1=$sub1'\n'$line
            fi
        fi            
    done
}

next_sub2()
{
        f2line=""
        while [[ ! $f2line =~ $timePattern ]]; do
            if ! read -r f2line <&7; then
                eof2=1
                break
            fi
        done
        ftimeString2=`echo $f2line|cut -d' ' -f 1`
        ltimeString2=`echo $f2line|cut -d' ' -f 3`
        ftime2=`echo $ftimeString2 |sed 's/,/./g' |awk -F: '{ printf( "%.3f \n",$1*3600 + $2*60 + $3) }'`
        ltime2=`echo $ltimeString2 |sed 's/,/./g' |awk -F: '{ printf( "%.3f \n",$1*3600 + $2*60 + $3) }'`
        sub2=""
        while [[ ! -z $f2line ]]; do
            read -r f2line <&7
            if [[ ! -z $f2line ]]; then
                if [[ -z $sub2 ]]; then
                    sub2=$f2line
                else
                    sub2=$sub2'\n'$f2line
                fi
            fi
       done 
}


generate_srt_subs()
{
#srt generation global variables
sval=1
exec 6<"${sub[1]}-temp"
exec 7<"${sub[2]}-temp"
timePattern=[0-9][0-9]:[0-9][0-9]:[0-9][0-9],[0-9][0-9][0-9]\ --\>\ [0-9][0-9]:[0-9][0-9]:[0-9][0-9],[0-9][0-9][0-9]
ftimeString=""
ltimeString=""
ftime=0
ltime=0
ftimeString2=""
ltimeString2=""
ftime2=0
ltime2=0
sub1=""
sub2=""
eof1=0
eof2=0
epsilon=0.3

rm "$output">/dev/null 2>&1
next_sub1
next_sub2
while [[ $eof1 -eq 0 && $eof2 -eq 0 ]]; do

    fdiff=$(echo "$ftime-$ftime2"|bc)
    fdiff=${fdiff#-}
    ldiff=$(echo "$ltime-$ltime2"|bc)
    ldiff=${ldiff#-}
    if [[ $eof1 -eq 1 && $eof2 -eq 0 ]];then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString2' --> '$ltimeString2>>$output
        echo -e $sub2'\n'>>$output
        next_sub2
    elif [[ $eof1 -eq 0 && $eof2 -eq 1 ]];then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString' --> '$ltimeString>>$output
        echo -e $sub1>>$output
        next_sub1
    elif [[ $(echo "$fdiff <= $epsilon"|bc) -eq 1 &&  $(echo "$ldiff <= $epsilon"|bc) -eq 1 ]]; then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString' --> '$ltimeString>>$output
        echo -e $sub1>>$output
        echo -e $sub2'\n'>>$output
        next_sub1
        next_sub2
    elif [[  $(echo "$ltime <= $ftime2"|bc) -eq 1 ]]; then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString' --> '$ltimeString>>$output
        echo -e $sub1'\n'>>$output
        next_sub1
    elif [[  $(echo "$ltime2 <= $ftime"|bc) -eq 1 ]]; then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString2' --> '$ltimeString2>>$output
        echo -e $sub2'\n'>>$output
        next_sub2
    elif [[  $(echo "$ftime < $ftime2"|bc) -eq 1 &&  $(echo "$ltime > $ftime2"|bc) -eq 1 ]]; then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString' --> '$ftimeString2>>$output
        echo -e $sub1'\n'>>$output
        ftimeString=$ftimeString2
        ftime=$ftime2
    elif [[  $(echo "$ftime2 < $ftime"|bc) -eq 1 &&  $(echo "$ltime2 > $ftime"|bc) -eq 1 ]]; then
        echo $sval>>$output
        sval=`expr $sval + 1`
        echo $ftimeString2' --> '$ftimeString>>$output
        echo -e $sub2'\n'>>$output
        ftimeString2=$ftimeString
        ftime2=$ftime
    elif [[  $(echo "$fdiff <= $epsilon"|bc) -eq 1 ]]; then
        if [[  $(echo "$ltime < $ltime2"|bc) -eq 1 ]]; then
            echo $sval>>$output
            sval=`expr $sval + 1`
            echo $ftimeString' --> '$ltimeString>>$output
            echo -e $sub1>>$output
            echo -e $sub2'\n'>>$output
            ftimeString2=$ltimeString
            ftime2=$ltime
            next_sub1
        else
            echo $sval>>$output
            sval=`expr $sval + 1`
            echo $ftimeString' --> '$ltimeString2>>$output
            echo -e $sub1>>$output
            echo -e $sub2'\n'>>$output
            ftimeString=$ltimeString2
            ftime=$ltime2
            next_sub2
        fi
    fi
echo -ne 'sub n°:'$sval'\r'
done
exec 6<&-
exec 7<&-
}

if [ $arg_count -eq 0 ]; then
	show_help
	exit 0
fi

eval last_arg='$'${arg_count}
prec_count=`expr $arg_count - 1`
eval prec_arg='$'${prec_count}

for param in $*
do
	if [ $param = "--help" ]; then show_help; exit 0; fi
done

if [ "$movie" = "--detect" ]; then
	movie="${sub[1]}"
	output="${movie%.*}-bilingual.ass"
	> "$output" #|| { echo "Can't write here! Exiting.." && echo 1; }
	detect_subtitles
fi

if [ ! -f "$movie" ]; then echo "Movie file ($movie) does not exist. Going back to shell.."; exit 1; fi
if [ ! -f "${sub[1]}" ]; then echo "Subtitle1 file (${sub[1]}) does not exist. Going back to shell.."; exit 1; fi
if [ ! -f "${sub[2]}" ]; then echo "Subtitle2 file (${sub[2]}) does not exist. Going back to shell.."; exit 1; fi

echo "Processing.."
convert_subs

if [ "$last_arg" = "--srt" -o "$prec_arg" = "--srt" ]; then
    # reset output
    output="${movie%.*}-bilingual.srt"
    > "$output" #|| { echo "Can't write here! Exiting.." && echo 1; }
    generate_srt_subs
else
    # reset output
    output="${movie%.*}-bilingual.ass"
    > "$output" #|| { echo "Can't write here! Exiting.." && echo 1; }
    generate_ssa_header
    generate_ssa_dialogs
fi

remove_temp_files
if [ "$last_arg" = "-pm" -o "$last_arg" = "--play-movie" -o  "$prec_arg" = "-pm" -o "$prec_arg" = "--play-movie" ]; then
	play_movie
	delete_output
fi

exit 0

# set +x

#depends on bc



