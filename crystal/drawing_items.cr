class DrawingItem
  @source_name = ""

  def source_name
    @source_name
  end

  def draw(left_separator, right_separator, source, steps_colors, bold)
    print ""
  end
end

class LeftMost < DrawingItem

  def draw(a, b, c, d, e)
    print "\e[0;H"
  end
end

class RightMost < DrawingItem
  @cols = 80

  def initialize
    @cols = `tput cols`.chomp.to_i
  end

  def draw(a, b, c, d, e)
    print "\e[0;#{@cols}H"
  end
end

class DrawingSource < DrawingItem
  @logo = Logo.new({ ".*" => "?" })
  @steps = [0]
  @prefix = ""
  @suffix = ""
  @interpreted_prefix = ""
  @interpreted_suffix = ""

  def logo(value)
    @logo.val.each do |k, v|
      reg_str = "^#{k}$"
      if value.to_s.match %r[#{reg_str}]
        return v
      end
    end
  end

  def self.htc(hex)
    hex.scan(/../).map{ |x| x[0].to_i(16)}.join(";")
  end
  
  def self.fgc(color)
    "[38;2;#{htc(color)}m"
  end

  def self.bgc(color)
    "[48;2;#{htc(color)}m"
  end

  def self.bgc_fgc(a, b)
    "#{bgc(a)}#{fgc(b)}"
  end

  def self.endfg
    "[39m"
  end

  def self.endbg
    "[49m"
  end

  def self.prefix(a)
    "Prefix(#{a} )"
  end

  def self.suffix(a)
    "Suffix(#{a})"
  end

  def self.interprete(s)
    s.clone.gsub("${endfg}", self.endfg)
      .gsub("${endbg}", self.endbg)
        .gsub(/\${fgc ([^}]+)}/) { |x| c = $~; self.fgc(c[1]) }
        .gsub(/\${bgc ([^}]+)}/) { |x| c = $~; self.bgc(c[1]) }
        .gsub(/\${bgc_fgc ([^}]+) ([^}]+)}/) { |x| c = $~;self.bgc_fgc(c[1], c[2]) }

  end

  def interprete_separators(s, left_separator, right_separator)
    s.gsub("${ls}", left_separator)
      .gsub("${rs}", right_separator)
  end

  def weight(bold, value)
    if bold
      "\e[1m#{value}\e[22m"
    else
      value
    end
  end

  def colorize(value, color)
    "\e[38:2:#{color}m%3d\e[39m" % value
  end

  def colorize_with_steps(source, value, steps_colors)
    if source.is_a? IntSource
      value = value.to_s.to_i
      steps = @steps
      if @steps[0] > @steps[1]
        steps_colors = steps_colors.reverse
        steps = steps.reverse
      end
      color = if value < steps[0]
                steps_colors[0]
              elsif value < steps[1]
                steps_colors[1]
              else
                steps_colors[2]
              end
      colorize value, color
    else
      value
    end
  end

  def initialize(source_name, steps, logo, prefix, suffix) 
    @steps = steps
    @source_name = source_name
    @logo = Logo.from_s logo
    @prefix = prefix
    @interpreted_prefix = DrawingSource.interprete(prefix)
    @suffix = suffix
    @interpreted_suffix = DrawingSource.interprete(suffix)
  end

  def self.extract_one_argument(name, vals, fallback, pattern="[^\)]")
    res = vals.match(/#{name}\((#{pattern}*)\)/)
    if res
      res[1]
    else
      fallback
    end
  end

  def self.extract_suffix(vals)
    extract_one_argument("Suffix", vals, "")
  end

  def self.extract_prefix(vals)
    extract_one_argument("Prefix", vals, "")
  end

  def self.extract_logo(vals)
    extract_one_argument("Logo", vals, ".*:", ".")
  end

  def self.extract_thresholds(vals)
    res = vals.match(/Thresholds\(([0-9]+),([0-9]+)\)/)
    if res
      [res[1].to_i, res[2].to_i]
    else
      [0, 0]
    end
  end


  def to_s(kind)
    "#{kind}::#{@source_name}=Prefix(#{@prefix}) Suffix(#{@suffix}) Thresholds(#{@steps.join(",")}) Logo(#{@logo.to_s})"
  end
end

class Left < DrawingSource
  @previous_value = ""

  def draw(left_separator, right_separator, source, steps_colors, bold)
    @previous_value ||= ""
    value = source.get
    delta_s = ""
    if !source.is_a? IntSource
      value_s = value.to_s
      delta = @previous_value.size - value_s.size
      delta_s = delta > 0 ?  " " * (delta + 1) : ""
      @previous_value = value_s
    end
    print weight bold, interprete_separators("#{@interpreted_prefix} #{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit} #{@interpreted_suffix}#{delta_s}", left_separator, right_separator)
  end

  def self.from_s(name, vals)
    self.new(name, extract_thresholds(vals), extract_logo(vals), extract_prefix(vals), extract_suffix(vals))
  end

  def to_s
    super("left")
  end
end

class Right < DrawingSource

  def draw(left_separator, right_separator, source, steps_colors, bold)
    value = source.get
    s_colorized = weight bold, interprete_separators("#{@interpreted_prefix} #{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit}#{@interpreted_suffix}", left_separator, right_separator)
    back = "\e[#{s_colorized.gsub(/\e\[[^m]*m/, "").size}D"
    print "#{back}#{s_colorized}#{back}"
  end

  def self.from_s(name, vals)
    self.new(name, extract_thresholds(vals), extract_logo(vals), extract_prefix(vals), extract_suffix(vals))
  end

  def to_s
    super("right")
  end
end


