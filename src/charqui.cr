require "option_parser"
require "./cli"
require "colorize"

module Charqui
  cli = CLI.new
  begin
    cli.parse
    cli.execute
  rescue ex
    print "ERROR: ".colorize(:red), ex.message, "\n"
    exit 1
  end
end
