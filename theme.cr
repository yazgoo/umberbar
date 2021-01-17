require "file_utils"

class Theme

  def self.select_load_or_save(theme_selected, theme, save_conf)
    FileUtils.mkdir_p(base_path) if !File.directory?(base_path)
    conf_exists = File.exists?(Theme.path)
    theme = (theme_selected || !conf_exists ? Theme.from_name(theme) : Theme.load)
    theme.with_args!(ARGV)
    theme.save if !conf_exists || save_conf
    theme
  end

  def self.base_path
    "#{ENV["HOME"]}/.config/umberbar/"
  end

  def self.path
    "#{base_path}/umberbar.conf"
  end

  def self.override_path
    "#{base_path}/override.conf"
  end

  def self.list
    ["black", "white", "black-no-nerd", "white-no-nerd", "black-flames", "black-ice", "black-powerline", "black-circle"]
  end

  def self.positions
    ["top", "bottom"]
  end
  @version = ""
  @term = ""
  @terminal_width = -1
  @font = ""
  @font_spacing = 0
  @bold = false
  @left_separator = ""
  @right_separator = ""
  @bg_color = ""
  @fg_color = ""
  @position = ""
  @font_size = ""
  @steps_colors = [""]
  @refreshes = "10"
  @lefts = [Left.new("left", [0, 1], ".*:left", "", "")]
  @rights = [Right.new("right", [0, 1], ".*:right", "", "")]
  @custom_sources = [CustomSource.new("dat", "date")]
  @last_update = 0

  def initialize(version, term, font, terminal_width, font_spacing, bold, left_separator, right_separator, bg_color, fg_color, position, font_size, steps_colors, refreshes, custom_sources, lefts, rights)
    if version != VERSION
      puts "the configuration version you tried to load (#{version}) is uncompatible with this program (#{VERSION})"
      puts "this probably means that configuration format changed between the two versions. You can either:"
      puts "- bypass this check altogether (at your own risk) by updating the version in #{Theme.path}"
      puts "- fix your configuration manually"
      puts "- override your configuration with an existing theme (e.g. -t black -s)"
      exit 1
    end
    @last_update = `date +%s`.to_i
    @version = version 
    @term = term
    @font = font 
    @terminal_width = terminal_width
    @bold = bold
    @left_separator = left_separator 
    @right_separator = right_separator 
    @bg_color = bg_color 
    @fg_color = fg_color 
    @position = Theme.positions.index(position).nil? ? Theme.positions[0] : position
    @font_size = font_size 
    @steps_colors = steps_colors 
    @refreshes = refreshes
    @custom_sources = custom_sources
    @lefts = lefts 
    @rights = rights 
  end

  def file_changed?(path)
    `stat -c '%Y' #{path}`.to_i > @last_update
  end

  def changed?
    file_changed?(Theme.path) || file_changed?(Theme.override_path)
  end

  def terminal_width
    @terminal_width
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

  def font_spacing
    @font_spacing
  end

  def term
    @term
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

  def custom_sources
    @custom_sources
  end

  def steps_colors
    @steps_colors
  end

  def bold
    @bold
  end

  def refreshes
    @refreshes.to_i
  end

  def self.get_font_spacing(term, font_size)
    if term == "xterm"
      if font_size.to_i < 13 
        -2 
      elsif font_size.to_i < 18
        -3
      elsif font_size.to_i < 23
        -4
      elsif font_size.to_i < 30
        -5
      else
        -6
      end
    else
      if font_size.to_i < 3
        1
      elsif font_size.to_i < 6
        0
      elsif font_size.to_i < 8
        -1
      elsif font_size.to_i < 11
        -2 
      elsif font_size.to_i < 13
        -3
      elsif font_size.to_i < 16
        -4
      elsif font_size.to_i < 18
        -5
      elsif font_size.to_i < 21
        -6
      else
        -7
      end
    end
  end
  
  def self.fgc(color)
    "[38;2;#{color}m"
  end

  def self.bgc(color)
    "[48;2;#{color}m"
  end

  def self.bgc_fgc(a, b)
    "#{bgc(a)}#{fgc(b)}"
  end

  def self.endc
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

  def self.nerd_with_colors(a, b, c, d, e, left_separator, right_separator)
    o = "0;0;0"
    {
      "bat" => [prefix(bgc_fgc(a,b)), suffix(bgc_fgc(c,a) + left_separator + endc)].join(" "),
      "cpu" => [prefix(bgc(c)),       suffix(bgc_fgc(d,c) + left_separator + endc)].join(" "),
      "tem" => [prefix(bgc(d)),       suffix(bgc_fgc(b,d) + left_separator + endc)].join(" "),
      "win" => [prefix(bgc(b)),       suffix(endbg + fgc(b) + left_separator + endc)].join(" "),

      "dat" => [prefix(bgc_fgc(d,c) + "" + right_separator + bgc(c) + endc), suffix(" ")].join(" "),
      "mem" => [prefix(bgc_fgc(b,d) + " " + right_separator + bgc(d) + endc), suffix(" ")].join(" "),
      "vol" => [prefix(endbg + fgc(b) + "" + right_separator + bgc(b) + endc), suffix(" ")].join(" "),
    }
  end

  def self.htc(hex)
    hex.scan(/../).map{ |x| x[0].to_i(16)}.join(";")
  end

  def self.from_name(name)
    flames = name.match /.*flames.*/
    ice = name.match /.*ice.*/
    powerline = name.match /.*powerline.*/
    circle = name.match /.*circle.*/
    prefixes_suffixes = flames ? 
    Theme.nerd_with_colors("100;100;100", "40;40;40", "80;80;80", "60;60;60", "0;0;0", "", " ")    
    : ice ? Theme.nerd_with_colors("0;168;204", "20;40;80", "12;123;147", "39;73;109", "0;0;0", "", " ")    
      : powerline ? Theme.nerd_with_colors("239;79;79", "116;199;184", "255;205;163", "238;149;149", "0;0;0", "", "")    
      : circle ? Theme.nerd_with_colors(htc("00af91"), htc("007965"), htc("f58634"), htc("ffcc29"), "0;0;0", "", "")    
        : { "bat" => "", "cpu" => "", "tem" => "", "win" => "", "dat" => "", "mem" => "", "vol" => "" }
    black = name.match /.*black.*/
    bg_color, fg_color = black ? ["black", "grey"] : ["white", "black"]
    fg_color = "black" if powerline || circle
    nerd = name.match(/.*no-nerd.*/).nil?
    font_size = "11"
    self.new(
      version = "#{VERSION}",
      term = "xterm",
      font = "DroidSansMono#{nerd ? " Nerd Font" : ""}",
      terminal_width = -1,
      font_spacing = get_font_spacing(term, font_size),
      bold = false,
      left_separator = "#{ice || flames || powerline || circle ? "" : nerd ? "" : "|"}",
      right_separator = "#{ice || flames || powerline || circle ? "" : nerd ? "" : "|"}",
      bg_color = "#{bg_color}",
      fg_color = "#{fg_color}",
      position = "top",
      font_size,
      steps_colors = powerline || circle ? ["0:95:0", "65:95:0", "95:0:0"] : ["0:165:0", "255:165:0", "255:0:0"],
      refreshes = "10",
      custom_sources = [CustomSource.new("dat", "date | sed -E 's/:[0-9]{2} .*//'")],
      [
      Left.from_s("bat", "#{prefixes_suffixes["bat"]} Thresholds(60,20) Logo(#{nerd ? NerdBatteryLogo.new.to_s : SingleLogo.new("bat").to_s})") ,
      Left.from_s("cpu", "#{prefixes_suffixes["cpu"]} Thresholds(40,70)   Logo(#{SingleLogo.new(nerd ? " " : "cpu").to_s})") ,
      Left.from_s("tem", "#{prefixes_suffixes["tem"]} Thresholds(40,75)   Logo(#{SingleLogo.new(nerd ? " " : "tem").to_s})") ,
      Left.from_s("win", "#{prefixes_suffixes["win"]} Thresholds(0,0)     Logo(#{nerd ? NerdWindowLogo.new.to_s : SingleLogo.new("win").to_s})") ,
    ],
    [
      Right.from_s("dat", "#{prefixes_suffixes["dat"]} Thresholds(0,0)    Logo(#{SingleLogo.new(nerd ? " ": "dat").to_s})"),
      Right.from_s("mem", "#{prefixes_suffixes["mem"]} Thresholds(30,70)  Logo(#{SingleLogo.new(nerd ? " ": "mem").to_s})"),
      Right.from_s("vol", "#{prefixes_suffixes["vol"]} Thresholds(60,120) Logo(#{nerd ? NerdVolumeLogo.new.to_s : SingleLogo.new("vol").to_s})") 
    ])
  end

  def to_s
    "# target version for configuration\n" + \
    "version=#{@version}\n" + \
    "# term inal to use\n" + \
      "term=#{@term}\n" + \
      "# xterm font (a list can be retrieved with fc-list)\n" + \
      "font=#{@font}\n" + \
      "# bold font (either false or true) \n" + \
      "bold=#{@bold}\n" + \
      "# separator between gauges aligned left\n" + \
      "left_separator=#{@left_separator}\n" + \
      "# separator between gauges aligned right\n" + \
      "right_separator=#{@right_separator}\n" + \
      "# xterm background color (see -bg in man xterm) \n" + \
      "bg_color=#{@bg_color}\n" + \
      "# xterm background color (see -fg in man xterm) \n" + \
      "fg_color=#{@fg_color}\n" + \
      "# position (available: #{Theme.positions})\n" + \
      "position=#{@position}\n" + \
      "# font size in pixel\n" + \
      "font_size=#{@font_size}\n" + \
      "# font spacing in pixel, usually negative (number of pixel between each character, optional)\n" + \
      "font_spacing=#{@font_spacing}\n" + \
      "# terminal width in characters (if set to -1, will set it based on font spacing and font size)\n" + \
      "terminal_width=#{@terminal_width}\n" + \
      "# thresholds colors for gauges\n" + \
      "# there are three colors in R:G:B format\n" + \
      "steps_colors=#{@steps_colors.join(" ")}\n" + \
      "# time between two bar refreshes in seconds\n" + \
      "refreshes=#{@refreshes}\n" + \
      "# custom sources allow to define your own commands as gauges sources\n" + \
      "# named like this custom::<name of source>\n" + \
      "# then you specify the command you want to run (can be a custom script)\n" + \
      @custom_sources.map { |src| "custom::#{src.name}=#{src.command}" }.join("\n") + "\n" + \
      "# lefts are gauges aligned to the left\n" + \
      "# named like this left::<name of source>\n" + \
      "# (builtin sources include: bat, cpu, temp, win, vol, mem)\n" + \
      "# then you specify a list of parameters for the gauge\n" + \
      "#      Prefix(<text>):            text to prefix the gauge with\n" + \
      "#      Suffix(<text>):            text to end the gauge with\n" + \
      "#      Thresholds(a,b):           thresholds value for coloring the gauge\n" + \
      "#                                 coloring is based on steps_color\n" + \
      "#                                 if a > b, colors will be applierd in reverse order\n" + \
      "#      Logo(<reg match list>):    logo to display based on the value of the gauge\n" + \
      "#                                 should be the last field\n" + \
      "#                                 consist of a list of regexp to match with logos\n" + \
      @lefts.map { |l| l.to_s }.join("\n") + "\n" + \
      "# right are gauges aligned to the right\n" + \
      "# they are configured like lefts\n" + \
      @rights.map { |l| l.to_s }.join("\n") + "\n"
  end

  def self.from_s(conf_s)
    conf = hash_from_key_value_array(conf_s.split("\n").select { |x| !x.match(/^#.*/) }.map { |x| x.split("=") }.select { |x| x.size == 2 })
    custom_sources = conf.select { |x, y| x.match /custom::.*/ }.map { |x, y| CustomSource.new(x.sub(/.*::/, ""), y) }
    lefts = conf.select { |x, y| x.match /left::.*/ }.map { |x, y| Left.from_s x.sub(/.*::/, ""), y }
    rights = conf.select { |x, y| x.match /right::.*/ }.map { |x, y| Right.from_s x.sub(/.*::/, ""), y }
    font_size = conf["font_size"].to_s
    term = conf["term"] || "xterm"
    self.new(
      version = conf["version"],
      term,
      font = conf["font"],
      terminal_width = conf["terminal_width"].to_i || -1,
      font_spacing = conf.has_key?("font_spacing") ? conf["font_spacing"].to_i : get_font_spacing(term, font_size.to_i),
      bold = conf["bold"] == "true",
      left_separator = conf["left_separator"].to_s,
      right_separator = conf["right_separator"].to_s,
      bg_color = conf["bg_color"].to_s,
      fg_color = conf["fg_color"].to_s,
      position = conf["position"].to_s,
      font_size,
      steps_colors = conf["steps_colors"].split(" "),
      refreshes = conf["refreshes"].to_s,
      custom_sources,
      lefts,
      rights
      )
  end

  def self.load
    s = File.read(self.path)
    s += "\n" + File.read(self.override_path) if File.exists?(self.override_path)
    self.from_s(s)
  end

  def save
    File.write(Theme.path, to_s)
  end

  def with_arg(args, name)
    i = args.index name
    if !i.nil?
      yield args[i + 1]
    end
  end

  def with_flag(args, name)
    i = args.index name
    if !i.nil?
      yield
    end
  end

  def self.args_help
    puts "Theme overriding:\n\n" \
      "-f  <font>        font\n" \
      "-te <term>        terminal to use\n" \
      "-b                bold (default to false)\n" \
      "-ls <separator>   left separator\n" \
      "-rs <separator>   right separator\n" \
      "-bg <color>       bg color\n" \
      "-fg <color>       fg color\n" \
      "-p  <position>    bar position (available: #{Theme.positions})\n" \
      "-fs <size>        font size\n" \
      "-fsp <spacing>    font spacing: pixels number between each character, usually negative\n"
      "-w <size>         number of chars of the terminal\n"
      "-sc <colors>      steps colors\n"
      "-r <seconds>      time between two bar refreshes\n"
  end

  def with_args!(args)
    with_arg(args, "-f") { |x| @font  = x }
    with_arg(args, "-te") { |x| @term  = x }
    with_flag(args, "-b") { @bold = true }
    with_arg(args, "-ls") { |x| @left_separator  = x }
    with_arg(args, "-rs") { |x| @right_separator  = x }
    with_arg(args, "-bg") { |x| @bg_color  = x }
    with_arg(args, "-fg") { |x| @fg_color  = x }
    with_arg(args, "-p") { |x| @position  = x }
    with_arg(args, "-fs") { |x| @font_size  = x }
    with_arg(args, "-sc") { |x| @steps_colors  = x.split(" ") }
    with_arg(args, "-r") { |x| @refreshes  = x }
    with_arg(args, "-fsp") { |x| @font_spacing  = x.to_i }
    with_arg(args, "-w") { |x| @terminal_width  = x.to_i }
    self
  end
end

