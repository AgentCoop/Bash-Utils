#! /bin/bash

set -e

PADDING_FILTER="pad=ih*16/9:ih:(ow-iw)/2:(oh-ih)/2,scale="
INPUT=
INPUT_RES_Y=
INPUT_REGEXP=
INPUT_ASPECT_RATIO=
OUTPUT_SPEC=
DRY_RUN=

PROCESSED_COUNT=

is_corrupted() {
    local input="$1"
    
    if [[ ! -f $input ]]; then
        return 1
    fi

    if ffprobe "$input" >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

input_to_ouptut() {
    local output=$(echo basename "$INPUT" | awk "match(\$0, \"$INPUT_REGEXP\", m) {printf \"$OUTPUT_SPEC\", m[1],m[2],m[3],m[4],m[5],m[6]}" \
        | sed "s/\s/_/g" \
        | sed "s/['\",]//g" \
        | sed 's/\]//g' \
        | sed 's/_-_/_/g' \
        | sed 's/\[//g' \
        | sed 's/&/_and_/g')

    if [[ -z $output ]]; then
        exit -1
    fi

    echo $output
}

get_aspect_ratio() {
    local input="$1"
    echo $(ffprobe "$input" 2>&1 | awk 'match($0, /DAR\s+([0-9]+:[0-9]+)/, m) { print m[1] }')
}

get_video_res_y() {
    local input="$1"

    resy=$(ffprobe "$input" 2>&1 | grep 'SAR' | grep -oP '\d{3,4}x\d{3,4}' | cut -d 'x' -f2 | head -n 1)

    echo $resy
}

convert-240p() {
    local output="./videos/240p/${OUTPUT_PREFIX}_240.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    [[ ! -d ./videos/240p ]] && mkdir -p ./videos/240p

    if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
        local filter="-vf ${PADDING_FILTER}426:240"
    else
        local filter="-vf scale=426:240"
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo
    else
        /usr/bin/ffmpeg -i "$INPUT" -sn -movflags faststart -strict -2 -crf 28 $filter "$output"
    fi
}

convert-360p() {
    local output="./videos/360p/${OUTPUT_PREFIX}_360.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    [[ ! -d ./videos/360p ]] && mkdir -p ./videos/360p

    if [[ $INPUT_ASPECT_RATIO!= 16:9 ]]; then
        local filter="-vf ${PADDING_FILTER}640:360"
    else
        local filter="-vf scale=640:360"
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo         
    else
        /usr/bin/ffmpeg -i "$INPUT" -sn -movflags faststart -strict -2 -crf 28 $filter "$output"
    fi
}

convert-480p() {
    local output="./videos/480p/${OUTPUT_PREFIX}_480.mp4"
    
    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]] || [[ $INPUT_RES_Y -lt 480 ]]; then
        return
    fi

    [[ ! -d ./videos/480p ]] && mkdir -p ./videos/480p

    if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
        local filter="-vf ${PADDING_FILTER}854:480"
    else
        local filter="-vf scale=854:480"
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo         
    else
        /usr/bin/ffmpeg -i "$INPUT" -sn -movflags faststart -strict -2 -crf 28 $filter "$output"
    fi
}

convert-720p() {
    local output="./videos/720p/${OUTPUT_PREFIX}_720.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]] || [[ $INPUT_RES_Y -lt 720 ]]; then
        return
    fi

    [[ ! -d ./videos/720p ]] && mkdir -p ./videos/720p

    if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
        local filter="-vf ${PADDING_FILTER}1280:720"
    else
        local filter="-vf scale=1280:720"
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo            
    else
        /usr/bin/ffmpeg -i "$INPUT" -sn -movflags faststart -strict -2 -crf 28 $filter "$output"
    fi
}

convert-1080p() {
    local output="./videos/1080p/${OUTPUT_PREFIX}_1080.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]] || [[ $INPUT_RES_Y -lt 800 ]]; then
        return
    fi

    [[ ! -d ./videos/1080p ]] && mkdir -p ./videos/1080p

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo          
    else
        /usr/bin/ffmpeg -i "$INPUT" -sn -movflags faststart -strict -2 -crf 28 -vf scale=1920:1080 "$output"
    fi
}

entrypoint() {
    INPUT_ASPECT_RATIO=$(get_aspect_ratio "$INPUT")
    INPUT_RES_Y=$(get_video_res_y "$INPUT")
    OUTPUT_PREFIX=$(input_to_ouptut)

    if [[  -f batch.stats ]]; then
        PROCESSED_COUNT=$(cat batch.stats | cut -f 1)
    else
        PROCESSED_COUNT=0
    fi 


    if [[ $CONVERT_240 = true ]]; then
        convert-240p
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_360 = true ]]; then
        convert-360p
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_480 = true ]]; then
        convert-480p
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_720 = true ]]; then
        convert-720p
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_1080 = true ]]; then
        convert-1080p
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    echo "$PROCESSED_COUNT" > batch.stats
}

args=$(getopt --long format:,input:,input-regexp:,output-spec:,dry-run -o "f:i:r:o:n:h" -- "$@")

while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                   ;;
                -i|--input)
                    INPUT="$2"
                ;;
                -n|--dry-run)
                    DRY_RUN=true
                ;;
                -r|--input-regexp)
                    INPUT_REGEXP="$2"
                ;;
                -o|--output-spec)
                    OUTPUT_SPEC="$2"
                ;;
                -f|--format)
                    case $2 in
                        240)
                            CONVERT_240=true
                        ;;
                        360)
                            CONVERT_360=true
                        ;;
                        480)
                            CONVERT_480=true
                        ;;
                        720)
                            CONVERT_720=true
                        ;;
                        1080)
                            CONVERT_1080=true
                        ;;
                        *)
                            echo 'Invalid video format'
                            exit 1
                        ;;
                    esac
                    shift
                    ;;
                -h)
                        echo "Display some help"
                        exit 0
                        ;;
        esac

        shift
done

entrypoint "$*"
