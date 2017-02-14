#! /bin/bash

set -ex

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
        /usr/bin/ffmpeg -i "$input" -sn -movflags faststart -strict -2 -crf 28 "$output"
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

    if [[ $# -eq 1 ]]; then
        convert-240p "$input"
        convert-360p "$input"
        convert-480p "$input"
        convert-720p "$input"
        convert-1080p "$input"
        exit 0
    fi

    while getopts ":f:" opt; do
        case $opt in
            f)
                case $OPTARG in
                    240)
                        convert-240p "$input"
                    ;;
                    360)
                        convert-360p "$input"
                    ;;
                    480)
                        convert-480p "$input"
                    ;;
                    720)
                        convert-720p "$input"
                    ;;
                    1080)
                        convert-1080p "$input"
                    ;;
                    *)
                        echo 'Invalid video format'
                        exit 1
                    ;;
                esac
            ;;
        esac
    done

}

entrypoint "$@"
