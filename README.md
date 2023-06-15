# charqui
A ffmpeg wrapper in order to target filesize rather than quality.

## Usage
```
charqui: A tool to convert a video to a target filesize.

Usage: charqui input_video.mp4 -o output_video.mp4 -s 10MB
    -h, --help                       Show this help
    -o OUTPUT, --output=OUTPUT       Name of the output file, default: output.mp4
    -r RATIO, --ratio=RATIO          Ratio between video/audio on target size, default 4:1
    -s SIZE, --size=SIZE             Target size, you can use plain bytes or abbreviations (in uppercase),
                                      example: 10MB, 100KB, etc. Default: 5MB
```

## Contributing

1. Fork it (<https://github.com/etra0/charqui/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Sebastián Aedo](https://github.com/etra0) - creator and maintainer
