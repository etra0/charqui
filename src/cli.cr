require "./size_parser"

module Charqui
  class CLI
    @input_name = Path.new
    @output_name : (Nil | Path)
    @ratio = 0.8
    # Target size in KB, default is 5MB.
    @target_size = 5 * 1024

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

        parser.on("-o OUTPUT", "--output=OUTPUT", "Name of the output file, default: output.mp4") do |name|
          @output_name = Path.new name
        end

        parser.on("-r RATIO", "--ratio=RATIO", "Ratio between video/audio on target size, default 4:1") do |ratio|
          self.parse_ratio ratio
        end

        parser.on("-s SIZE", "--size=SIZE",
                  <<-STRING
                  Target size, you can use plain bytes or abbreviations (in uppercase),
                   example: 10MB, 100KB, etc. Default: 5MB
                  STRING
                 ) do |size|
          self.parse_size size
        end

        parser.unknown_args do |rem|
          raise "Missing input file" if rem.empty?
          raise "We only support one file as input" if rem.size > 1

          @input_name = Path.new rem[0]
        end

      end

      # In the future we may actually support webm, I guess.
      @output_name = Path.new("output.mp4") if @output_name.nil?
    end

    def parse_ratio(ratio : String)
      vid, sound = ratio.split(":").map &.to_f
      total = vid + sound
      @ratio = vid / total
    end

    def parse_size(size : String)
      @target_size = SizeKB.parse size
    end

    def get_encoder : String
      buffer = IO::Memory.new
      Process.run("ffmpeg", ["-version"], output: buffer)
      output = buffer.to_s

      # Ugh, for some reason, videotoolbox seems to ignore bitrate param? or
      # are we missing something. For now let's just leave it commented.
      # TODO: check h264_nvenc.
      # return "h264_videotoolbox" if output.includes? "videotoolbox"
      return "libx264"
    end

    def execute
      # First we get the duration of the clip
      raise "Input file #{@input_name} doesn't exists." if !File.exists?(@input_name)

      if File.size(@input_name) / 1024 <= @target_size
        raise "Target file size is actually bigger than the original file."
      end

      buffer = IO::Memory.new
      Process.run("ffprobe",
        ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
           @input_name.to_s],
        output: buffer)
      duration = buffer.to_s.to_f
      buffer.clear

      Process.run("ffprobe",
        ["-v", "error", "-select_streams", "a:0", "-show_entries",
           "stream=bit_rate", "-of", "csv=p=0", @input_name.to_s],
        output: buffer)
      # We need the audio rate in KiB
      # TODO: add a way to keep current audio_rate.
      audio_rate = buffer.to_s.to_f / 1024
      buffer.clear

      target_sz_kib = @target_size * 8 / duration
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
      puts "Running first pass..."
      Process.run("ffmpeg", 
        ["-i", @input_name.to_s, "-c:v", encoder, "-b:v",
         "#{video_rate.to_i}K", "-an", "-f", "mp4", "-pass", "1", null_output,
         "-y", "-hide_banner", "-loglevel", "error", "-stats"],
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      puts "Running second pass..."
      Process.run("ffmpeg",
         ["-i", @input_name.to_s, "-c:v", encoder, "-b:v",
          "#{video_rate.to_i}K", "-c:a", "aac", "-b:a", "#{audio_rate.to_i}K",
          "-f", "mp4", "-pass", "2", @output_name.to_s, "-hide_banner",
          "-loglevel", "error", "-stats"],
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit,
          input: Process::Redirect::Inherit,
      )
      puts "Deleting ffmpeg pass files..."
      Dir.glob("ffmpeg2pass-*") do |f|
        File.delete f
      end
    end
  end

end
