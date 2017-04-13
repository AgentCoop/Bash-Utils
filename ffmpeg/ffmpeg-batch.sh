#! /bin/bash

set -e

PADDING_FILTER="pad=ih*16/9:ih:(ow-iw)/2:(oh-ih)/2,scale="
INPUT=
INPUT_RES_Y=
INPUT_REGEXP=
INPUT_ASPECT_RATIO=
INPUT_AUDIOFORMAT=
INPUT_AUDIOBITRATE=
OUTPUT_SPEC=
DRY_RUN=

VIDEO_STREAM=0:0
AUDIO_STREAM=0:1
VIDEO_CODEC=libx264 # or copy
AUDIO_BITRATE=192

PROCESSED_COUNT=
BATCH_MODE=no

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
        | sed 's/(.*)//g' \
        | sed "s/['\",\(\)]//g" \
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

get_audio_bitrate() {
    local input="$1"
    echo $(ffprobe "$input" 2>&1 | awk "match(\$0, /Stream #${AUDIO_STREAM}.*Audio.*, ([0-9]+) kb\/s.*/, m) { print m[1] }")
}

get_audio_format() {
    local input="$1"
    echo $(ffprobe -loglevel error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$input")
}

get_video_res_y() {
    local input="$1"

    resy=$(ffprobe "$input" 2>&1 | grep 'SAR' | grep -oP '\d{3,4}x\d{3,4}' | cut -d 'x' -f2 | head -n 1)

    echo $resy
}

transcode() {
    local yres="$1"

    if [[ $BATCH_MODE == "no" ]]; then
        local output="${OUTPUT_PREFIX}_${yres}.mp4"
    else
        local output="./videos/${yres}p/${OUTPUT_PREFIX}_${yres}.mp4"
        [[ ! -d "./videos/${yres}p" ]] && mkdir -p "./videos/${yres}p"
    fi

    if [ -f "$output" ]; then
        exit
    fi

    case $yres in
        240)
            if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
                local scaling="-vf ${PADDING_FILTER}426:240"
            else
                local scaling="-vf scale=426:240"
            fi
        ;;
        360)
            if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
                local filter="-vf ${PADDING_FILTER}640:360"
            else
                local filter="-vf scale=640:360"
            fi
        ;;
        480)
            if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
                local scaling="-vf ${PADDING_FILTER}854:480"
            else
                local scaling="-vf scale=854:480"
            fi
        ;;
        720)
            if [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
                local scaling="-vf ${PADDING_FILTER}1280:720"
            else
                local scaling="-vf scale=1280:720"
            fi
        ;;
        1080)
            local scaling="-vf scale=1920:1080"
        ;; 
    esac

    if [[ $INPUT_AUDIOFORMAT == 'aac' ]] && [[ -z $AUDIO_BITRATE ]]; then
        local audio_ops='-c:a copy'
    elif
        local audio_ops="-c:a aac -b:a ${AUDIO_BITRATE}k"
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo
    elif [[ $MAKE_SAMPLE = true ]]; then
        /usr/bin/ffmpeg -t '00:32' -ss '00:05:00' -i "$INPUT" -y -map $VIDEO_STREAM -map $AUDIO_STREAM -c:v $VIDEO_CODEC $audio_ops -ac 2 -movflags faststart -strict -2 -crf 28 $scaling "sample_${yres}.mp4"
    else
        /usr/bin/ffmpeg -i "$INPUT" -map $VIDEO_STREAM -map $AUDIO_STREAM -c:v $VIDEO_CODEC -c:a $audio_ops -ac 2 -movflags faststart -strict -2 -crf 28 $scaling "$output"
    fi    
}


entrypoint() {
    INPUT_ASPECT_RATIO=$(get_aspect_ratio "$INPUT")
    INPUT_RES_Y=$(get_video_res_y "$INPUT")
    
    if [[ $MAKE_SAMPLE != true ]]; then
        OUTPUT_PREFIX=$(input_to_ouptut)
    fi
    
    INPUT_AUDIOFORMAT=$(get_audio_format "$INPUT")
    INPUT_AUDIOBITRATE=$(get_audio_bitrate "$INPUT")

    if [[ $INPUT_AUDIOBITRATE -lt $AUDIO_BITRATE ]]; then
        echo "Input audio bitrate ${INPUT_AUDIOBITRATE}k must be greater than specified output ${AUDIO_BITRATE}k"
        exit
    fi

    if [[  -f batch.stats ]]; then
        PROCESSED_COUNT=$(cat batch.stats | cut -f 1)
    else
        PROCESSED_COUNT=0
    fi

    if [[ $CONVERT_240 = true ]]; then
        transcode 240
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_360 = true ]]; then
        transcode 360
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_480 = true ]]; then
        transcode 480
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_720 = true ]]; then
        transcode 720
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    if [[ $CONVERT_1080 = true ]]; then
        transcode 1080
        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi

    echo "$PROCESSED_COUNT" > batch.stats
}

args=$(getopt --long format:,input:,input-regexp:,output-spec:,audio-stream:,video-stream:,dry-run,make-sample,vc,vs,ab -o "f:i:r:o:A:V:Bn:h" -- "$@")

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
                -B)
                    BATCH_MODE="yes"
                ;;                
                --vc)
                    VIDEO_CODEC="$2"
                ;;
                -V|--video-stream)
                    VIDEO_STREAM="$2"
                ;;
                -A|--audio-stream)
                    AUDIO_STREAM="$2"
                ;;
                --ab)
                    AUDIO_BITRATE="$2"
                ;;
                --make-sample)
                    MAKE_SAMPLE=true
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
