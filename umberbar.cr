#!/usr/bin/env ruby

def is_ruby?
  __FILE__.match /.*.rb$/
end

def hash_from_key_value_array(array)
  array.map { |x| x[0] }.zip(array.map {|x| x[1]}).to_h
end

class Source
  def unit
    ""
  end
  def get
    ""
  end
end

class IntSource < Source
end

class TemperatureSource < IntSource
  def unit
    "°C"
  end
end

class PercentSource < IntSource
  def unit
    "%"
  end
end

class Memory < PercentSource
  def extract(hash, key)
    reg = / *(\d+) *.*/
    match = reg.match hash[key]
    if match
      match[1].to_i
    else
      0
    end
  end
  def get
    lines = File.read("/proc/meminfo").split("\n").map { |line| line.split(":") }.select { |x| x.size == 2 }
    contents = hash_from_key_value_array lines
    mem_total = extract(contents, "MemTotal")
    ((mem_total - extract(contents, "MemFree") - extract(contents, "Cached") - extract(contents, "SReclaimable") + extract(contents, "Shmem")) * 100 / mem_total).to_i
  end
end

class Date < Source
  def unit
    ""
  end
  def get
    (is_ruby? ? `date`.chomp : Time.local.to_s).sub(/:[0-9]{2} .*/, "")
  end
end

class Battery < PercentSource
  @path = "/sys/class/power_supply/cw2015-battery"
  def initialize
    @path = "/sys/class/power_supply/cw2015-battery"
    if !File.directory?(@path)
      @path = "/sys/class/power_supply/BAT0"
    end
  end
  def get
    value = File.read(@path + "/capacity").chomp.to_i
    File.read(@path + "/status").chomp == "Full" ? 100 : value 
  end
end

class CpuTemperatureSource < TemperatureSource
  def get
    (File.read("/sys/class/thermal/thermal_zone0/temp").chomp.to_i / 1000).to_i
  end
end

class Cpu < PercentSource
  @last_idle = 0
  @last_total = 0
  def initialize
    @last_idle = 0
    @last_total = 0
  end
  def get
    values = File.read("/proc/stat").split("\n")[0].sub(/^cpu */, "").split(" ").map{|x| x.to_i}
    idle = values[3]
    total = values.reduce(0) { |acc, i| acc + i }
    res = total == @last_total ? 0 : 100 - ( ( 100 * (idle  - @last_idle)) / (total - @last_total))
    @last_total = total
    @last_idle = idle
    res.to_i
  end
end

class Volume < PercentSource
  def get
    reg = /^.*\[([0-9]+)%\].*\[(.*)\]$/
    mixer_out = `amixer sget Master`.split("\n").map { |x| res = reg.match(x.chomp); res ? (res[2] == "on" ? res[1].to_i : 0 ): nil }.select { |x| !x.nil? }.first
  end
end

class WindowCommand < Source
  def get
    `xdotool getwindowfocus getwindowname`.chomp
  end
end

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
  @logo = { ".*" => "?" }
  @steps = [0]
  def logo(value)
    @logo.each do |k, v|
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
    @logo = logo
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
end

class Right < DrawingSource
  def draw(left_separator, right_separator, source, steps_colors)
    value = source.get
    s = " #{right_separator} #{logo value} #{value}#{source.unit}"
    s_colorized = " #{right_separator} #{logo value} #{colorize_with_steps(source, value, steps_colors)}#{source.unit}"
    back = "\e[#{s.size}D"
    print "#{back}#{s_colorized}#{back}"
  end
end

class Bar
  def left_gravity(sym)
  end
  @sources = { "bat" => Source.new }
  @left_separator = ""
  @right_separator = ""
  @bg_color = ""
  @fg_color = ""
  @font_size = ""
  @steps_colors = [""]
  @bar = [DrawingItem.new]
  @font = "DroidSansMono"
  def initialize(font, left_separator, right_separator, bg_color, fg_color, font_size, steps_colors, bar)
    @font = font
    @sources = { "bat" => Battery.new, "cpu" => Cpu.new, "tem" => CpuTemperatureSource.new, "win" => WindowCommand.new, "vol" => Volume.new, "mem" => Memory.new, "dat" => Date.new }
    @bar = bar
    @left_separator = left_separator
    @right_separator = right_separator
    @bg_color = bg_color
    @fg_color = fg_color
    @font_size = font_size
    @steps_colors = steps_colors
  end
  def draw
    @bar.each do |item|
      if @sources.has_key? item.source_name
        item.draw(@left_separator, @right_separator, @sources[item.source_name], @steps_colors)
      else
        item.draw "", "", Source.new, [""]
      end
    end
  end
  def screen_width
    result = `xrandr`.split("\n").map { |x| x.match /^ *([0-9]+)x.*\*.*$/ }.select { |x| !x.nil? }  
    default = [0, 1920]
    if result.size > 0 
      first = result[0] || default
      first[1].to_i
    else
      default[1]
    end
  end
  def run
    if ARGV.size >= 1 && ARGV[0] == "xterm"
      screen_char_width = (screen_width / ( @font_size.to_i - 2 )).to_i
      font = is_ruby? ? @font.split(" ").join("\\ ") : @font
      additional_args = ["-fa", font, "-fs", @font_size, "-fullscreen", "-geometry", "#{screen_char_width}x1+0+0", "-bg", @bg_color, "-fg", @fg_color, "-class", "xscreensaver", "-e"]
      if is_ruby?
        args = (["xterm"] + additional_args + [__FILE__])
        Process.exec(args.join(" "))
      else
        Process.exec("xterm", additional_args + [PROGRAM_NAME])
      end
    else
      print `tput civis`
      while true
        draw
        sleep 5
      end
    end
  end
  def self.logos_from_str(val)
    hash_from_key_value_array(val.split("-").map{ |x| l = x.split(":"); [l[0], l[1]] })
  end
  def self.left_from(name, vals)
    Left.new(name, [vals[0].to_i, vals[1].to_i], logos_from_str(vals[2]))
  end
  def self.right_from(name, vals)
    Right.new(name, [vals[0].to_i, vals[1].to_i], logos_from_str(vals[2]))
  end
  def self.main
    default_conf = "#{ENV["HOME"]}/.config/umberbar.conf"
    if !File.exists?(default_conf)
      contents = "version=0.1\n" + \
        "font=DroidSansMono Nerd Font\n" + \
        "left_separator=\n" + \
        "right_separator=\n" + \
        "bg_color=black\n" + \
        "fg_color=grey\n" + \
        "font_size=9\n" + \
        "steps_colors=0:165:0 255:165:0 255:0:0\n" + \
        "left::bat=60 20 .:-1.:-2.:-3.:-4.:-5.:-6.:-7.:-8.:-9.:-100:\n" + \
        "left::cpu=40 70 .*: \n" + \
        "left::tem=30 50 .*:\n" + \
        "left::win=0  0  .*:  \n" + \
        "right::dat=0  0  .*: \n" + \
        "right::mem=30 70 .*: \n" + \
        "right::vol=60 120 0:🔇-.*:🔊"
      File.write(default_conf, contents)
    end
    conf = hash_from_key_value_array(File.read(default_conf).split("\n").map { |x| x.split("=") }.select { |x| x.size == 2 })
    lefts = conf.select { |x, y| x.match /left::.*/ }.map { |x, y| left_from x.sub(/.*::/, ""), y.split }
    rights = conf.select { |x, y| x.match /right::.*/ }.map { |x, y| right_from x.sub(/.*::/, ""), y.split }
    bar = Bar.new(
      font = conf["font"],
      left_separator = conf["left_separator"].to_s,
      right_separator = conf["right_separator"].to_s,
      bg_color = conf["bg_color"].to_s,
      fg_color = conf["fg_color"].to_s,
      font_size = conf["font_size"].to_s,
      steps_colors = conf["steps_colors"].split(" "),
      [LeftMost.new] + lefts + [RightMost.new] + rights
    )
    bar.run
  end
end

Bar.main