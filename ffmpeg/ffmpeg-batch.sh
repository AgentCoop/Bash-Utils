#! /bin/bash

set -e

RED='\033[0;31m'
NC='\033[0m' # No Color

PADDING_FILTER="pad=ih*16/9:ih:(ow-iw)/2:(oh-ih)/2"
INPUT=
INPUT_RES_Y=
INPUT_REGEXP=
INPUT_ASPECT_RATIO=
INPUT_AUDIOFORMAT=
INPUT_AUDIOBITRATE=
OUTPUT_SPEC=
DRY_RUN=
CRF=28

VIDEO_STREAM=0:0
AUDIO_STREAM=0:1

VIDEO_NO_PADDING=false
COPY_AUDIO=false
BATCH_MODE=no

err() {
    (>&2 echo -e "${RED}${1}${NC}")
    echo
    exit -1
}

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
    local abitrate="$2"

    if [[ $BATCH_MODE == "no" ]]; then
        local output="${OUTPUT_PREFIX}_${yres}p.mp4"
    else
        local output="./videos/${yres}p/${OUTPUT_PREFIX}_${yres}p.mp4"
        [[ ! -d "./videos/${yres}p" ]] && mkdir -p "./videos/${yres}p"
    fi

    if [ -f "$output" ]; then
        if [ ! -s "$output" ]; then # remove zero bytes files
            rm -f "$output"
        else
            return
        fi
    fi

    local filter_ops="-vf "
    local crf_ops="-crf $CRF"

    if [[ $VIDEO_NO_PADDING = false ]] && [[ $INPUT_ASPECT_RATIO != 16:9 ]]; then
        filter_ops="${filter_ops} ${PADDING_FILTER},"
    fi

    case $yres in
        240)
            local filter_ops="${filter_ops}scale=426:240"
        ;;
        360)
            local filter_ops="${filter_ops}scale=640:360"
        ;;
        480)
            local filter_ops="${filter_ops}scale=854:480"
        ;;
        720)
            if [[ ! $INPUT_RES_Y -eq 720 ]]; then
                filter_ops="-vf scale=1280:720"
            else
                filter_ops=""
            fi
        ;;
        1080)
            if [[ ! $INPUT_RES_Y -eq 1080 ]]; then
                filter_ops="-vf scale=1920:1080"
            else
                filter_ops=""
            fi
        ;;
    esac

    if [[ $COPY_AUDIO = true ]]; then
        local audio_ops="-c:a copy"
    else
        if [[ ! -z $INPUT_AUDIOBITRATE ]] && [[ $abitrate -gt $INPUT_AUDIOBITRATE ]]; then
            if [[ $INPUT_AUDIOFORMAT == 'aac' ]]; then
                local audio_ops="-c:a copy"
            else
                local audio_ops="-c:a aac -b:a ${INPUT_AUDIOBITRATE}k -ac 2"
            fi
        else
            local audio_ops="-c:a aac -b:a ${abitrate}k -ac 2"
        fi
    fi

    if [[ $DRY_RUN = true ]]; then
        echo "INPUT: $INPUT"
        echo "OUTPUT: $output"
        echo "Audio options: $audio_ops"
        echo 
    elif [[ $MAKE_SAMPLE = true ]]; then
        /usr/bin/ffmpeg -t '00:32' -ss '00:05:00' -i "$INPUT" -y -map $VIDEO_STREAM -map $AUDIO_STREAM -c:v libx264 $audio_ops -sn -movflags faststart -strict -2 $crf_ops $filter_ops "sample_${yres}.mp4"
    else
        /usr/bin/ffmpeg -i "$INPUT" -map $VIDEO_STREAM -map $AUDIO_STREAM -c:v libx264 $audio_ops -sn -movflags faststart -strict -2 $crf_ops $filter_ops "$output"
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

    if [[ $COPY_AUDIO != true ]] && [[ "$INPUT_AUDIOFORMAT" != "aac" ]] && [[ -z $INPUT_AUDIOBITRATE ]]; then
        err "Failed to determine input audio bitrate"
    fi

    if [[ $CONVERT_240 = true ]]; then
        transcode 240 64
    fi

    if [[ $CONVERT_360 = true ]]; then
        transcode 360 128
    fi

    if [[ $CONVERT_480 = true ]]; then
        transcode 480 128
    fi

    if [[ $CONVERT_720 = true ]]; then
        transcode 720 192
    fi

    if [[ $CONVERT_1080 = true ]]; then
        transcode 1080 192
    fi
}

args=$(getopt --long format:,input:,input-regexp:,output-spec:,audio-stream:,video-stream:,video-no-padding,copy-audio,dry-run,make-sample,crf: -o "f:i:r:o:A:V:Bh" -- "$@")

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
                --crf)
                    CRF="$2"
                ;;
                --copy-audio)
                    COPY_AUDIO=true
                ;;
                -V|--video-stream)
                    VIDEO_STREAM="$2"
                ;;
                -A|--audio-stream)
                    AUDIO_STREAM="$2"
                ;;
                --video-no-padding)
                    VIDEO_NO_PADDING=true
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
