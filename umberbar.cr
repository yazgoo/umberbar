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

class Theme
  def self.list
    ["black", "white", "black-no-nerd", "white-no-nerd"]
  end
  @name = "black"
  def initialize(name)
    @name = name
    if Theme.list.index(name).nil? 
      @name = Theme.list[0] 
    end
  end
  def nerd?
    @name.match(/.*no-nerd.*/).nil?
  end
  def black?
    @name.match /.*black.*/
  end
  def to_s
    bg_color, fg_color = black? ? ["black", "grey"] : ["white", "black"]
    "version=0.1\n" + \
      "font=DroidSansMono Nerd Font\n" + \
      "left_separator=#{nerd? ? "" : "|"}\n" + \
      "right_separator=#{nerd? ? "" : "|"}\n" + \
      "bg_color=#{bg_color}\n" + \
      "fg_color=#{fg_color}\n" + \
      "position=top\n" + \
      "font_size=9\n" + \
      "steps_colors=0:165:0 255:165:0 255:0:0\n" + \
      "left::bat=60 20 #{nerd? ? ".:-1.:-2.:-3.:-4.:-5.:-6.:-7.:-8.:-9.:-100:" : ".*:bat"}\n" + \
      "left::cpu=40 70 .*:#{nerd? ? " " : "cpu"}\n" + \
      "left::tem=30 50 .*:#{nerd? ? " " : "tem"}\n" + \
      "left::win=0  0  .*:#{nerd? ? "  ": "win"}\n" + \
      "right::dat=0  0  .*:#{nerd? ? " ": "dat"}\n" + \
      "right::mem=30 70 .*:#{nerd? ? " ": "mem"}\n" + \
      "right::vol=60 120 #{nerd? ? "0:🔇-.*:🔊" : ".*:vol" }"
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
  @position = ""
  @font_size = ""
  @steps_colors = [""]
  @bar = [DrawingItem.new]
  @font = "DroidSansMono"
  @embedded = false
  def initialize(font, left_separator, right_separator, bg_color, fg_color, position, font_size, steps_colors, bar, embedded)
    @font = font
    @sources = { "bat" => Battery.new, "cpu" => Cpu.new, "tem" => CpuTemperatureSource.new, "win" => WindowCommand.new, "vol" => Volume.new, "mem" => Memory.new, "dat" => Date.new }
    @bar = bar
    @left_separator = left_separator
    @right_separator = right_separator
    @bg_color = bg_color
    @fg_color = fg_color
    @position = position
    @font_size = font_size
    @steps_colors = steps_colors
    @embedded = embedded
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
  def screen_size
    result = `xrandr`.split("\n").map { |x| x.match /^ *([0-9]+)x([0-9]+) *.*\*.*$/ }.select { |x| !x.nil? }  
    default = ["0", "800", "600"]
    out = default
    if result.size > 0 
      first = result[0] || default
      out = first
    end
    [out[1].to_i, out[2].to_i]
  end
  def run
    if !@embedded
      screen_dimension = screen_size
      screen_char_width = (screen_dimension[0] / ( @font_size.to_i - 2 )).to_i
      font = is_ruby? ? @font.split(" ").join("\\ ") : @font
      y = @position == "bottom" ? (screen_dimension[1] - @font_size.to_i * 2) : 0
      additional_args = ["-fa", font, "-fs", @font_size, "-fullscreen", "-geometry", "#{screen_char_width}x1+0+#{y}", "-bg", @bg_color, "-fg", @fg_color, "-class", "xscreensaver", "-e"]
      program_args = ARGV.join(" ")
      if is_ruby?
        args = (["xterm"] + additional_args + ["\"#{__FILE__} -e #{program_args}\""])
        Process.exec(args.join(" "))
      else
        Process.exec("xterm", additional_args + [PROGRAM_NAME + " -e #{program_args}"])
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
  def self.get_conf
    theme = "black"
    theme_selected = false
    theme_index = ARGV.index("-t")
    if theme_index
      theme_selected = true
      theme = ARGV[theme_index + 1]
    end
    conf_path = "#{ENV["HOME"]}/.config/umberbar.conf"
    save_conf = ARGV.index("-s")
    conf_s = theme_selected ? Theme.new(theme).to_s : File.read(conf_path)
    File.write(conf_path, conf_s) if !File.exists?(conf_path) || save_conf
    hash_from_key_value_array(conf_s.split("\n").map { |x| x.split("=") }.select { |x| x.size == 2 })
  end
  def self.help
    puts \
      "-h          display this help\n" \
      "-e          embed in a terminal\n" \
      "-t <theme>  load a specific theme (available: #{Theme.list})\n" \
      "-s          save selected theme in configuration"
    exit
  end
  def self.main
    self.help if ARGV.index("-h")
    embedded = !ARGV.index("-e").nil?
    conf = self.get_conf
    lefts = conf.select { |x, y| x.match /left::.*/ }.map { |x, y| left_from x.sub(/.*::/, ""), y.split }
    rights = conf.select { |x, y| x.match /right::.*/ }.map { |x, y| right_from x.sub(/.*::/, ""), y.split }
    bar = Bar.new(
      font = conf["font"],
      left_separator = conf["left_separator"].to_s,
      right_separator = conf["right_separator"].to_s,
      bg_color = conf["bg_color"].to_s,
      fg_color = conf["fg_color"].to_s,
      position = conf["position"].to_s,
      font_size = conf["font_size"].to_s,
      steps_colors = conf["steps_colors"].split(" "),
      [LeftMost.new] + lefts + [RightMost.new] + rights,
      embedded
    )
    bar.run
  end
end

Bar.main
