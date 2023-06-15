require "option_parser"

require "./cli"

module Charqui
  CLI.new.parse
end
