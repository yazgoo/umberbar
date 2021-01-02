class Logo
  @hash = { ".*" => "logo" }

  def initialize(hash)
    @hash = hash
  end

  def self.from_s(val)
    self.new hash_from_key_value_array(val.split("-").map{ |x| l = x.split(":"); [l[0], l[1]] })
  end

  def to_s
    @hash.map { |x, y| "#{x}:#{y}" }.join("-")
  end

  def val
    @hash
  end
end

class SingleLogo < Logo

  def initialize(logo)
    super({ ".*" => logo })
  end
end

class NerdBatteryLogo < Logo

  def initialize
    super( {
      "."   => "",
      "1."  => "",
      "2."  => "",
      "3."  => "",
      "4."  => "",
      "5."  => "",
      "6."  => "",
      "7."  => "",
      "8."  => "",
      "9."  => "",
      "100" => ""
    })
  end
end

class NerdVolumeLogo < Logo

  def initialize
    super({ 
        "0"  => "🔇",
        ".*" => "🔊"
      })
  end
end
