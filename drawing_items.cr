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

  def logo(value)
    @logo.val.each do |k, v|
      reg_str = "^#{k}$"
      if value.to_s.match %r[#{reg_str}]
        return v
      end
    end
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
    @suffix = suffix
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
    print weight bold, "#{@prefix}#{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit} #{left_separator} #{@suffix}#{delta_s}"
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
    s_colorized = weight bold, "#{@prefix} #{right_separator} #{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit}#{@suffix}"
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


