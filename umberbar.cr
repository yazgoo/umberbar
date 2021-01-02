#!/usr/bin/env ruby

def is_ruby?
  __FILE__.match /.*.rb$/
end

def hash_from_key_value_array(array)
  array.map { |x| x[0] }.zip(array.map {|x| x[1]}).to_h
end

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
      "." => "",
      "1." => "",
      "2." => "",
      "3." => "",
      "4." => "",
      "5." => "",
      "6." => "",
      "7." => "",
      "8." => "",
      "9." => "",
      "100" => ""
    })
  end
end

class NerdVolumeLogo < Logo
  def initialize
    super({ 
        "0" => "🔇",
        ".*" => "🔊"
      })
  end
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
    res = total == @last_total ? 0 : 100 - (100 * (idle  - @last_idle).to_f) / (total - @last_total).to_f
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

class Theme
  def self.list
    ["black", "white", "black-no-nerd", "white-no-nerd"]
  end
  @version = ""
  @font = ""
  @left_separator = ""
  @right_separator = ""
  @bg_color = ""
  @fg_color = ""
  @position = ""
  @font_size = ""
  @steps_colors = [""]
  @lefts = [Left.new("left", [0, 1], ".*:left")]
  @rights = [Right.new("right", [0, 1], ".*:right")]
  def initialize(version, font, left_separator, right_separator, bg_color, fg_color, position, font_size, steps_colors, lefts, rights)
    @version = version 
    @font = font 
    @left_separator = left_separator 
    @right_separator = right_separator 
    @bg_color = bg_color 
    @fg_color = fg_color 
    @position = position 
    @font_size = font_size 
    @steps_colors = steps_colors 
    @lefts = lefts 
    @rights = rights 
  end
  def lefts
    @lefts
  end
  def rights
    @rights
  end
  def font
    @font
  end
  def left_separator
    @left_separator
  end
  def right_separator
    @right_separator
  end
  def bg_color
    @bg_color
  end
  def fg_color
    @fg_color
  end
  def position
    @position
  end
  def font_size
    @font_size
  end
  def steps_colors
    @steps_colors
  end
  def self.from_name(name)
    black = name.match /.*black.*/
    bg_color, fg_color = black ? ["black", "grey"] : ["white", "black"]
    nerd = name.match(/.*no-nerd.*/).nil?
    self.new(
      version = "0.1",
      font = "DroidSansMono#{nerd ? " Nerd Font" : ""}",
      left_separator = "#{nerd ? "" : "|"}",
      right_separator = "#{nerd ? "" : "|"}",
      bg_color = "#{bg_color}",
      fg_color = "#{fg_color}",
      position = "top",
      font_size = "9",
      steps_colors = ["0:165:0", "255:165:0", "255:0:0"],
      [
      Left.from("bat", ["60", "20", nerd ? NerdBatteryLogo.new.to_s : SingleLogo.new("bat").to_s]) ,
      Left.from("cpu", ["40", "70", SingleLogo.new(nerd ? " " : "cpu").to_s]) ,
      Left.from("tem", ["30", "50", SingleLogo.new(nerd ? " " : "tem").to_s]) ,
      Left.from("win", ["0", "0", SingleLogo.new(nerd ? "  ": "win").to_s]) ,
    ],
    [
      Right.from("dat", ["0", "0", SingleLogo.new(nerd ? " ": "dat").to_s]) ,
      Right.from("mem", ["30", "70", SingleLogo.new(nerd ? " ": "mem").to_s]) ,
      Right.from("vol", ["60", "120", nerd ? NerdVolumeLogo.new.to_s : SingleLogo.new("vol").to_s]) 
    ])
  end
  def to_s
    "version=#{@version}\n" + \
      "font=#{@font}\n" + \
      "left_separator=#{@left_separator}\n" + \
      "right_separator=#{@right_separator}\n" + \
      "bg_color=#{@bg_color}\n" + \
      "fg_color=#{@fg_color}\n" + \
      "position=#{@position}\n" + \
      "font_size=#{@font_size}\n" + \
      "steps_colors=#{@steps_colors.join(" ")}\n" + \
      @lefts.map { |l| l.to_s }.join("\n") + "\n" + \
      @rights.map { |l| l.to_s }.join("\n") + "\n"
  end
  def self.from_s(conf_s)
    conf = hash_from_key_value_array(conf_s.split("\n").map { |x| x.split("=") }.select { |x| x.size == 2 })
    lefts = conf.select { |x, y| x.match /left::.*/ }.map { |x, y| Left.from x.sub(/.*::/, ""), y.split }
    rights = conf.select { |x, y| x.match /right::.*/ }.map { |x, y| Right.from x.sub(/.*::/, ""), y.split }
    self.new(
      version = conf["version"],
      font = conf["font"],
      left_separator = conf["left_separator"].to_s,
      right_separator = conf["right_separator"].to_s,
      bg_color = conf["bg_color"].to_s,
      fg_color = conf["fg_color"].to_s,
      position = conf["position"].to_s,
      font_size = conf["font_size"].to_s,
      steps_colors = conf["steps_colors"].split(" "),
      lefts,
      rights
      )
  end
end

class Bar
  def left_gravity(sym)
  end
  @sources = { "bat" => Source.new }
  @bar = [DrawingItem.new]
  @embedded = false
  @theme = Theme.new("", "", "", "", "", "", "", "", [""], 
                     [Left.new("left", [0, 1], ".*:left")],
                     [Right.new("right", [0, 1], ".*:right")])
  def initialize(theme, embedded)
    @sources = { "bat" => Battery.new, "cpu" => Cpu.new, "tem" => CpuTemperatureSource.new, "win" => WindowCommand.new, "vol" => Volume.new, "mem" => Memory.new, "dat" => Date.new }
    @bar = ([LeftMost.new] + theme.lefts + [RightMost.new] + theme.rights)
    @theme = theme
    @embedded = embedded
  end
  def draw
    @bar.each do |item|
      if @sources.has_key? item.source_name
        item.draw(@theme.left_separator, @theme.right_separator, @sources[item.source_name], @theme.steps_colors)
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
      screen_char_width = (screen_dimension[0] / ( @theme.font_size.to_i - 2 )).to_i
      font = is_ruby? ? @theme.font.split(" ").join("\\ ") : @theme.font
      y = @theme.position == "bottom" ? (screen_dimension[1] - @theme.font_size.to_i * 2) : 0
      additional_args = ["-fa", font, "-fs", @theme.font_size, "-fullscreen", "-geometry", "#{screen_char_width}x1+0+#{y}", "-bg", @theme.bg_color, "-fg", @theme.fg_color, "-class", "xscreensaver", "-e"]
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
    conf_exists = File.exists?(conf_path)
    conf_s = theme_selected || !conf_exists ? Theme.from_name(theme).to_s : File.read(conf_path)
    File.write(conf_path, conf_s) if !conf_exists || save_conf
    Theme.from_s(conf_s)
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
    bar = Bar.new(
      conf,
      #[LeftMost.new] + lefts + [RightMost.new] + rights,
      embedded
    )
    bar.run
  end
end

Bar.main
