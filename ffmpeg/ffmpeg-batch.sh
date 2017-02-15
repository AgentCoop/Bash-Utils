#! /bin/bash

set -ex

PADDING_FILTER="-vf pad=ih*16/9:ih:(ow-iw)/2:(oh-ih)/2,scale="

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
    local input="$1"
    local output="./videos/240p/${input}_240.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    [[ ! -d ./videos/240p ]] && mkdir -p ./videos/240p

    /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 -vf scale=426:240 "$output"
}

convert-360p() {
    local input="$1"
    local output="./videos/360p/${input}_360.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    [[ ! -d ./videos/360p ]] && mkdir -p ./videos/360p
    /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 -vf scale=640:360 "$output"
}

convert-480p() {
    local input="$1"
    local output="./videos/480p/${input}_480.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    [[ ! -d ./videos/480p ]] && mkdir -p ./videos/480p
    resy=$(get_video_res_y "$input")

    if [[ $resy -gt 360 ]] && [[ ! $resy -eq 480 ]]; then
            /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 -vf scale=854:480 "$output"
    elif [[ $resy -eq 480 ]]; then
        local ratio=$(get_aspect_ratio "$input")

        if [[ $ratio == 4:3 ]]; then
            local filter="$PADDING_FILTER"854:480
        else
            local filter=
        fi

        /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 "$filter" "$output"
    fi
}

convert-720p() {
    local input="$1"
    local output="./videos/720p/${input}_720.mp4"
    
    resy=$(get_video_res_y "$input")
    [[ ! -d ./videos/720p ]] && mkdir -p ./videos/720p

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    if [[ $resy -gt 480 ]] && [[ ! $resy -eq 720 ]]; then
    /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 -vf scale=1280:720 "$output"
    elif [[ $resy -eq 720 ]]; then
        /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 "$output"
    fi
}

convert-1080p() {
    local input="$1"
    local output="./videos/1080p/${input}_1080.mp4"

    if is_corrupted "$output"; then
        rm -f "$output"
    fi

    if [[ -f $output ]]; then
        return
    fi

    resy=$(get_video_res_y "$input")
    [[ ! -d ./videos/1080p ]] && mkdir -p ./videos/1080p

    if [[ $resy -gt 720 ]] && [[ ! $resy -eq 1080 ]]; then
        /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 -vf scale=1920:1080 "$output"
    elif [[ $resy -eq 1080 ]]; then
        /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 "$output"
    fi
}

entrypoint() {
    local input="$1"

    if [[ $CONVERT_240 = true ]]; then
        convert-240p "$input"
    fi

    if [[ $CONVERT_360 = true ]]; then
        convert-360p "$input"
    fi

    if [[ $CONVERT_480 = true ]]; then
        convert-480p "$input"
    fi

    if [[ $CONVERT_720 = true ]]; then
        convert-720p "$input"
    fi

    if [[ $CONVERT_1080 = true ]]; then
        convert-1080p "$input"
    fi

}

while getopts ":f:" opt; do
    case $opt in
        f)
            case $OPTARG in
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
            shift
        ;;
    esac
done

entrypoint "$@"
