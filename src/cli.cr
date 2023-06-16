require "option_parser"
require "./charqui"
require "colorize"

module Charqui
  cli = CLI.new
  begin
    cli.parse
    cli.execute
  rescue ex : AppError
    print "ERROR: ".colorize(:red), ex.message, "\n"
    exit 1

  rescue ex
    trace = ex.backtrace.join("\n")
    print "FATAL ERROR: ".colorize(:red), ex.message, "\n", trace, "\n\n",
      <<-STRING
      This is an unexpected error, please report it in the issues tab of the
      repository: https://github.com/etra0/charqui/issues

      STRING
    exit 2
  end
end
