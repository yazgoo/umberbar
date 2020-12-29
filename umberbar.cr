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

class TemperatureSource < Source
  def unit
    "°C"
  end
end

class PercentSource < Source
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
    res = total == @last_total ? 0 : 100 - ( ( 100 * (idle  - @last_idle) / (total - @last_total)))
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
  @source_name = :none
  def source_name
    @source_name
  end
  def draw(left_separator, right_separator, source)
    print ""
  end
end

class LeftMost < DrawingItem
  def draw(a, b, c)
    print "\e[0;H"
  end
end

class RightMost < DrawingItem
  @cols = 80
  def initialize
    @cols = `tput cols`.chomp.to_i
  end
  def draw(a, b, c)
    print "\e[0;#{@cols}H"
  end
end

class DrawingSource < DrawingItem
  @logo = { /.*/ => "?" }
  def logo(value)
    @logo.each do |k, v|
      if value.to_s.match k
        return v
      end
    end
  end
  def initialize(source_name, logo) 
    @source_name = source_name
    @logo = logo
  end
end

class Left < DrawingSource
  def draw(left_separator, right_separator, source)
    value = source.get
    print "#{logo value} #{source.get}#{source.unit} #{left_separator} "
  end
end

class Right < DrawingSource
  def draw(left_separator, right_separator, source)
    value = source.get
    s = " #{right_separator} #{logo value} #{value}#{source.unit}"
    back = "\e[#{s.size}D"
    print "#{back}#{s}#{back}"
  end
end

class Bar
  def left_gravity(sym)
  end
  @sources = { :bat => Source.new }
  @left_separator = ""
  @right_separator = ""
  @bar = [DrawingItem.new]
  def initialize(sources, left_separator, right_separator, normal_color, bar)
    @sources = sources
    @bar = bar
    @left_separator = left_separator
    @right_separator = right_separator
  end
  def draw
    @bar.each do |item|
      if @sources.has_key? item.source_name
        item.draw(@left_separator, @right_separator, @sources[item.source_name])
      else
        item.draw "", "", Source.new
      end
    end
  end
  def run
    if ARGV.size == 1 && ARGV[0] == "xterm"
      screen_width = 1920
      font_size = 9
      screen_char_width = (screen_width / ( font_size - 2 )).to_i
      font = "DroidSansMono\\ Nerd\\ Font"
      bg_color = "black"
      fg_color = "white"
      additional_args = ["-fa", font, "-fs", font_size.to_s, "-fullscreen", "-geometry", "#{screen_char_width}x1+0+0", "-bg", bg_color, "-fg", fg_color, "-class", "xscreensaver", "-e"]
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
end

bar = Bar.new({ :bat => Battery.new, :cpu => Cpu.new, :tem => CpuTemperatureSource.new, :win => WindowCommand.new, :vol => Volume.new, :mem => Memory.new, :dat => Date.new },
  left_separator = "",
  right_separator = "",
  normal_color = "150:150:150",
  [
  LeftMost.new,
  Left.new(:bat, { /^.$/ => "", /^1.$/ => "", /^2.$/ => "", /^3.$/ => "", /^4.$/ => "", /^5.$/ => "", /^6.$/ => "", /^7.$/ => "", /^8.*/ => "", /.*/ => "" }),
  Left.new(:cpu, { /.*/ => " " }),
  Left.new(:tem, { /.*/ => ""  }),
  Left.new(:win, { /.*/ => " " }),
  RightMost.new,
  Right.new(:dat, { /.*/ => " " }),
  Right.new(:mem, { /.*/ => " " }),
  Right.new(:vol, { /0/ => "🔇", /.*/ => "🔊"}),
  ],
             )
bar.run
