require "./size_parser"

module Charqui
  class AppError < Exception
  end

  class CLI
    @input_name = Path.new
    @output_name : Path?
    @ratio = 0.8
    # Target size in KB, default is 24MB.
    @target_size = SizeKB.new
    @target_resolution : String?
    @keep_audio_quality = false

    getter ratio, target_size

    def parse
      OptionParser.parse do |parser|
        parser.banner = <<-STRING
          charqui: A tool to convert a video to a target filesize.

          Usage: charqui input_video.mp4 -o output_video.mp4 -s 10MB
          STRING
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit
        end

        parser.on("-o OUTPUT", "--output=OUTPUT",
                  "Name of the output file, default: output.mp4"
                 ) { |name| @output_name = Path.new name }

        parser.on("-p PROPORTION", "--proportion=PROPORTION",
                  "Ratio between video/audio on target size, default 4:1"
                 ) { |ratio| self.parse_ratio ratio }

        parser.on("-s SIZE", "--size=SIZE",
                  "Target size, example: 10MB, 100KB, etc. Default: 24MB (discord limit)"
                 ) { |sz| self.parse_size sz }

        parser.on("-r RESOLUTION", "--resolution",
                  <<-STRING
                  Target resolution. You only need to specify width,
                    for example, 1080, 720, 480, etc.
                  STRING
                ) { |res| @target_resolution = res }

        parser.on("-k", "--keep-audio-quality", "Keep the current audio quality. \n\
                 Warning: If the target size is too small, it might be not possible to achieve it since the size of the audio itself could be bigger."
                ) { @keep_audio_quality = true }

        parser.unknown_args do |rem|
          raise AppError.new "Missing input file." if rem.empty?
          raise AppError.new "We only support one file as input." if rem.size > 1

          @input_name = Path.new rem[0]
        end
      end

      @output_name ||= Path.new((@input_name.parent / @input_name.stem).to_s + "_#{@target_size.raw}.mp4")

      raise AppError.new "We only support mp4 as output for now." if @output_name.try &.extension != ".mp4"
    end

    def parse_ratio(ratio : String)
      begin
        vid, sound = ratio.split(":").map &.to_f
      rescue
        raise AppError.new "Invalid format of proportion (argument -p #{ratio}), make sure to use the format V:A (ex: 4:1)."
      end
      total = vid + sound
      @ratio = vid / total
    end

    def self.with_pipes(&block : IO::Memory, IO::Memory ->)
      input = IO::Memory.new
      output = IO::Memory.new
      yield input, output
    end

    def parse_size(size : String)
      @target_size = SizeKB.new size
    end

    def get_encoder : String
      output = CLI.with_pipes do |stdout, _|
        Process.run("ffmpeg", ["-version"], output: stdout)
        stdout.to_s
      end

      # For some reason, neither of these encoder can have precise control of
      # the bitrate, which means when we try to target a specific size, they
      # can be bigger which renders this tools unusable.
      # TODO: Investigate if we can solve this in the future.
      # return "h264_nvenc" if output.includes? "enable-nvenc"
      # return "h264_videotoolbox" if output.includes? "videotoolbox"
      return "libx264"
    end

    def execute
      if !Process.find_executable("ffmpeg") || !Process.find_executable("ffprobe")
        raise AppError.new "This tool depends on FFmpeg (with ffprobe), it has to be installed and in your PATH."
      end

      raise AppError.new "Input file #{@input_name} doesn't exists." if !File.exists?(@input_name)

      if File.size(@input_name) / 1024 <= @target_size.value
        raise AppError.new "Target file size is actually bigger than the original file."
      end

      # First we get the duration of the clip
      duration = CLI.with_pipes do |stdout, stderr|
        Process.run("ffprobe",
                    ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                     @input_name.to_s],
                     output: stdout, error: stderr)
        begin
          stdout.to_s.to_f
        rescue
          raise AppError.new "Couldn't get the duration of the video, got: `#{stderr.to_s}` instead."
        end
      end

      # We need the audio rate in KiB
      audio_rate_ffprobe = nil
      CLI.with_pipes do |stdout, stderr|
        Process.run("ffprobe",
                    ["-v", "error", "-select_streams", "a:0", "-show_entries",
                     "stream=bit_rate", "-of", "csv=p=0", @input_name.to_s],
                     output: stdout, error: stderr)
        begin
          audio_rate_ffprobe = stdout.to_s.to_f / 1024
        rescue
          puts "INFO: Couldn't get the audio bitrate, got `#{stderr.to_s}` instead."
          if @keep_audio_quality
            print "WARNING: ".colorize(:yellow), "-k argument will be ignored since the audio quality couldn't be calculated.\n"
          end
        end
      end

      target_sz_kib = @target_size.value * 8 / duration
      if audio_rate_ffprobe && @keep_audio_quality
        audio_rate = audio_rate_ffprobe
        video_rate = target_sz_kib - audio_rate_ffprobe
        if video_rate < 0
          print "WARNING: ".colorize(:yellow), "The video rate minus audio rate was less than 0, so using at least 100kb\n"
          video_rate = 100
        end
      else
        audio_rate = Math.min(target_sz_kib * (1 - @ratio), (audio_rate_ffprobe || Float32::MAX))
        video_rate = target_sz_kib - audio_rate
      end

      encoder = self.get_encoder
      puts "Using the #{encoder} encoder"

      prelude = ["-i", @input_name.to_s]
      video_settings = ["-c:v", encoder, "-b:v", "#{video_rate.to_i}K"]
      audio_settings = ["-c:a", "aac", "-b:a", "#{audio_rate.to_i}K"]
      final_params = ["-f", "mp4", "-hide_banner", "-loglevel", "error", "-stats"]

      if @target_resolution
        video_settings << "-vf"
        video_settings << "scale=-2:#{@target_resolution}"
      end

      puts "Running first pass..."
      # In the first pass we don't need to process the audio so we simply use
      # -an
      first_pass_args = prelude + video_settings + ["-an"] +
        final_params + ["-pass", "1", File::NULL, "-y"]
      Process.run("ffmpeg", first_pass_args, output: Process::Redirect::Inherit,
                  error: Process::Redirect::Inherit)

      output_name = @output_name.not_nil!
      puts "Running second pass..."
      second_pass_args = prelude + video_settings + audio_settings +
        final_params + ["-pass", "2", output_name.to_s]

      Process.run("ffmpeg", second_pass_args,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit,
          input: Process::Redirect::Inherit)

      puts
      puts "Video saved as #{output_name.to_s}"
      puts "Deleting ffmpeg pass files..."
      Dir.glob("ffmpeg2pass-*") do |f|
        File.delete f
      end
    end
  end

end
