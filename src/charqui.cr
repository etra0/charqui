require "./size_parser"

module Charqui
  class AppError < Exception
  end

  class CLI
    @input_name = Path.new
    @output_name : (Nil | Path)
    @ratio = 0.8
    # Target size in KB, default is 24MB.
    @target_size = SizeKB.new
    @target_resolution : (Nil | String)

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

        parser.on("-r RATIO", "--ratio=RATIO",
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

        parser.unknown_args do |rem|
          raise AppError.new "Missing input file." if rem.empty?
          raise AppError.new "We only support one file as input." if rem.size > 1

          @input_name = Path.new rem[0]
        end
      end

      @output_name = Path.new((@input_name.parent / @input_name.stem).to_s + "_#{@target_size.raw}.mp4") if @output_name.nil?

      raise AppError.new "We only support mp4 as output for now." if @output_name.try &.extension != ".mp4"
    end

    def parse_ratio(ratio : String)
      vid, sound = ratio.split(":").map &.to_f
      total = vid + sound
      @ratio = vid / total
    end

    def parse_size(size : String)
      @target_size = SizeKB.new size
    end

    def get_encoder : String
      buffer = IO::Memory.new
      Process.run("ffmpeg", ["-version"], output: buffer)
      output = buffer.to_s

      # For some reason, neither of these encoder can have precise control of
      # the bitrate, which means when we try to target a specific size, they
      # can be bigger which renders this tools unusable.
      # TODO: Investigate if we can solve this in the future.
      # return "h264_nvenc" if output.includes? "enable-nvenc"
      # return "h264_videotoolbox" if output.includes? "videotoolbox"
      return "libx264"
    end

    def execute
      if !Process.find_executable("ffmpeg")
        raise AppError.new "This tools depends on FFmpeg, it has to be installed and in your PATH."
      end

      raise AppError.new "Input file #{@input_name} doesn't exists." if !File.exists?(@input_name)

      if File.size(@input_name) / 1024 <= @target_size.value
        raise AppError.new "Target file size is actually bigger than the original file."
      end

      # First we get the duration of the clip
      err_output = IO::Memory.new
      buffer = IO::Memory.new
      Process.run("ffprobe",
        ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
           @input_name.to_s],
        output: buffer, error: err_output)
      begin
        duration = buffer.to_s.to_f
      rescue
        raise AppError.new "Couldn't get the duration of the video, got: `#{err_output.to_s}` instead."
      end
      buffer.clear
      err_output.clear

      # at this point, audio_rate is unused, but in the future we'd like to add
      # something like --keep_audio_quality or something.
      # We need the audio rate in KiB
      Process.run("ffprobe",
        ["-v", "error", "-select_streams", "a:0", "-show_entries",
           "stream=bit_rate", "-of", "csv=p=0", @input_name.to_s],
        output: buffer, error: err_output)
      begin
        audio_rate = buffer.to_s.to_f / 1024
      rescue
        puts "INFO: Couldn't get the audio bitrate, got `#{err_output.to_s}` instead."
      end
      buffer.clear
      err_output.clear

      target_sz_kib = @target_size.value * 8 / duration
      video_rate = target_sz_kib * @ratio
      audio_rate = target_sz_kib * (1 - @ratio)

      null_output : String
      {% if flag?(:win32) %}
      null_output = "nul"
      {% else %}
      null_output = "/dev/null"
      {% end %}

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
        final_params + ["-pass", "1", null_output, "-y"]
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

      puts "Deleting ffmpeg pass files..."
      Dir.glob("ffmpeg2pass-*") do |f|
        File.delete (output_name.parent / f)
      end
    end
  end

end
