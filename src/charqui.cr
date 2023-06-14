require "option_parser"

module Charqui
  class CLI
    @input_name = Path.new
    @output_name : (Nil | Path)
    @ratio = 0.8

    def parse
      OptionParser.parse do |parser|
        parser.banner = "Usage: charqui input_video.mp4 -o output_video.mp4 -s 10MB"
        parser.on("-h", "--help", "Show this help") { puts parser; exit }

        parser.on("-o", "--output", "Name of the output file") do |name|
          @output_name = Path.new name
        end

        parser.on("-r", "--ratio", "Ratio between video/audio on target size, default 4:1") do |ratio|
          self.parse_ratio ratio
        end

        parser.unknown_args do |rem|
          if rem.empty?
            raise "Missing input file"
          end

          @input_name = Path.new rem[0]
        end

      end

      @output_name = Path.new("output#{@input_name.extension}") if @output_name.nil?

      puts @output_name, @input_name, @ratio
    end

    def parse_ratio(ratio : String)
      puts "Parsing the #{ratio}!"
    end
  end

  CLI.new.parse
end
