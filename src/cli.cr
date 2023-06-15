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

      @output_name = Path.new("output#{@input_name.extension}") if @output_name.nil?
      puts @output_name, @input_name, @ratio
    end

    def parse_ratio(ratio : String)
      vid, sound = ratio.split(":").map &.to_f
      total = vid + sound
      @ratio = vid / total
    end

    def parse_size(size : String)
      puts "Parsing SIZE #{size}"
    end
  end

end
