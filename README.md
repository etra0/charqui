# charqui
A ffmpeg wrapper in order to target filesize rather than quality.

## Usage
```
charqui: A tool to convert a video to a target filesize.

Usage: charqui input_video.mp4 -o output_video.mp4 -s 10MB
    -h, --help                       Show this help
    -o OUTPUT, --output=OUTPUT       Name of the output file, default: output.mp4
    -r RATIO, --ratio=RATIO          Ratio between video/audio on target size, default 4:1
    -s SIZE, --size=SIZE             Target size, example: 10MB, 100KB, etc. Default: 24MB (discord limit)
    -r RESOLUTION, --resolution      Target resolution. You only need to specify width,
                                       for example, 1080, 720, 480, etc.
```
