class DrawingItem
  @source_name = ""

  def source_name
    @source_name
  end

  def draw(left_separator, right_separator, source, steps_colors)
    print ""
  end
end

class LeftMost < DrawingItem

  def draw(a, b, c, d)
    print "\e[0;H"
  end
end

class RightMost < DrawingItem
  @cols = 80

  def initialize
    @cols = `tput cols`.chomp.to_i
  end

  def draw(a, b, c, d)
    print "\e[0;#{@cols}H"
  end
end

class DrawingSource < DrawingItem
  @logo = Logo.new({ ".*" => "?" })
  @steps = [0]

  def logo(value)
    @logo.val.each do |k, v|
      reg_str = "^#{k}$"
      if value.to_s.match %r[#{reg_str}]
        return v
      end
    end
  end

  def colorize(value, color)
    "\e[38:2:#{color}m#{value}\e[m"
  end

  def colorize_with_steps(source, value, steps_colors)
    if source.is_a? IntSource
      value = value.to_s.to_i
      if @steps[0] > @steps[1]
        steps_colors = steps_colors.reverse
      end
      color = if value < @steps[0]
                steps_colors[0]
              elsif value < @steps[1]
                steps_colors[1]
              else
                steps_colors[2]
              end
      colorize value, color
    else
      value
    end
  end

  def initialize(source_name, steps, logo) 
    @steps = steps
    @source_name = source_name
    @logo = Logo.from_s logo
  end
end

class Left < DrawingSource
  @previous_value = ""

  def draw(left_separator, right_separator, source, steps_colors)
    @previous_value ||= ""
    value = source.get
    value_s = value.to_s
    delta = @previous_value.size - value_s.size
    delta_s = delta > 0 ?  " " * delta : ""
    print "#{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit} #{left_separator} #{delta_s}"
    @previous_value = value_s
  end

  def self.from(name, vals)
    self.new(name, [vals[0].to_i, vals[1].to_i], vals[2])
  end

  def to_s
    "left::#{@source_name}=#{@steps.join(" ")} #{@logo.to_s}"
  end
end

class Right < DrawingSource

  def draw(left_separator, right_separator, source, steps_colors)
    value = source.get
    s = " #{right_separator} #{logo value} #{value}#{source.unit}"
    s_colorized = " #{right_separator} #{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit}"
    back = "\e[#{s.size}D"
    print "#{back}#{s_colorized}#{back}"
  end

  def self.from(name, vals)
    self.new(name, [vals[0].to_i, vals[1].to_i], vals[2])
  end

  def to_s
    "right::#{@source_name}=#{@steps.join(" ")} #{@logo.to_s}"
  end
end


