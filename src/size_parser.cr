module Charqui
  struct SizeKB
    SIZE_FROM_KB = {
      "gb" => 1024 * 1024,
      "mb" => 1024,
      "kb" => 1
    }

    def self.parse(val : String) : Int
      value_to_parse = val.downcase
      expr = /(?<val>[0-9]+)(?<sz>mb|kb|gb)/.match(value_to_parse)
      value = 0
      begin
        val = $1.to_i
        sz = $2
        value = val * SIZE_FROM_KB[sz]
      rescue
        raise "Couldn't parse #{value_to_parse}, make sure to use proper size specifier."
      end
      return value
    end
  end
end
