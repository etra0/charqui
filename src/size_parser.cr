module Charqui
  struct SizeKB
    SIZE_FROM_KB = {
      "gb" => 1024 * 1024,
      "mb" => 1024,
      "kb" => 1
    }
    @value = 24 * 1024
    @raw : String
    getter value, raw

    def initialize(@raw : String = "24mb")
      self.parse
    end

    def parse
      value_to_parse = @raw.downcase
      expr = /(?<val>[0-9\.]+)(?<sz>mb|kb|gb)/.match(value_to_parse)
      value = 0
      begin
        val = $1.to_f
        sz = $2
        @value = (val * SIZE_FROM_KB[sz]).to_i
      rescue
        raise "Couldn't parse #{value_to_parse}, make sure to use proper size specifier."
      end
    end
  end
end
