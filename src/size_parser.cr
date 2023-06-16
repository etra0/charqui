module Charqui
  struct SizeKB
    SIZE_FROM_KB = {
      "gb" => 1024 * 1024,
      "mb" => 1024,
      "kb" => 1
    }
    @raw : String
    @value = 0
    getter value, raw

    def initialize(@raw : String = "24mb")
      @value = self.parse
    end

    private def parse : Int
      value_to_parse = @raw.downcase
      expr = /(?<val>[0-9\.]+)(?<sz>mb|kb|gb)$/.match(value_to_parse)
      begin
        val = $1.to_f
        sz = $2
        value = (val * SIZE_FROM_KB[sz]).to_i
      rescue
        raise AppError.new "Couldn't parse #{value_to_parse}, make sure to use proper size specifier."
      end
      return value
    end
  end
end
