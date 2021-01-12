class Theme

  def self.select_load_or_save(theme_selected, theme, save_conf)
    conf_exists = File.exists?(Theme.path)
    theme = (theme_selected || !conf_exists ? Theme.from_name(theme) : Theme.load)
    theme.with_args!(ARGV)
    theme.save if !conf_exists || save_conf
    theme
  end

  def self.path
    conf_path = "#{ENV["HOME"]}/.config/umberbar.conf"
  end

  def self.list
    ["black", "white", "black-no-nerd", "white-no-nerd", "black-flames", "black-ice", "black-powerline", "black-circle"]
  end

  def self.positions
    ["top", "bottom"]
  end
  @version = ""
  @font = ""
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
  @last_update = 0

  def initialize(version, font, bold, left_separator, right_separator, bg_color, fg_color, position, font_size, steps_colors, refreshes, lefts, rights)
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
    @font = font 
    @bold = bold
    @left_separator = left_separator 
    @right_separator = right_separator 
    @bg_color = bg_color 
    @fg_color = fg_color 
    @position = Theme.positions.index(position).nil? ? Theme.positions[0] : position
    @font_size = font_size 
    @steps_colors = steps_colors 
    @refreshes = refreshes
    @lefts = lefts 
    @rights = rights 
  end

  def changed?
    `stat -c '%Y' #{Theme.path}`.to_i > @last_update
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

  def bold
    @bold
  end

  def refreshes
    @refreshes.to_i
  end

  def font_spacing
      if @font_size.to_i < 13 
        -2 
      elsif @font_size.to_i < 18
        -3
      elsif @font_size.to_i < 23
        -4
      elsif @font_size.to_i < 30
        -5
      else
        -6
      end
  end

  def self.nerd_with_colors(a, b, c, d, e, left_separator, right_separator)
    { 
      "bat" => "Prefix([48;2;#{a}m[38;2;#{b}m ) Suffix([48;2;#{c}m[38;2;#{a}m#{left_separator}  [39m) ",
      "cpu" => "Prefix([48;2;#{c}m) Suffix([48;2;#{d}m[38;2;#{c}m#{left_separator}  [39m)",
      "tem" => "Prefix([48;2;#{d}m) Suffix([48;2;#{b}m[38;2;#{d}m#{left_separator}  [39m)",
      "win" => "Prefix([48;2;#{b}m) Suffix([48;2;0;0;0m[38;2;#{b}m#{left_separator}  [39m)",

      "dat" => "Prefix([48;2;#{d}m[38;2;#{c}m #{right_separator}[48;2;#{c}m[39m) Suffix( )",
      "mem" => "Prefix([48;2;#{b}m[38;2;#{d}m #{right_separator}[48;2;#{d}m[39m) Suffix( )",
      "vol" => "Prefix([48;2;#{e}m[38;2;#{b}m #{right_separator}[48;2;#{b}m[39m) Suffix( )",
    }
  end

  def self.htc(hex)
    hex.scan(/../).map{ |x| x[0].to_i(16)}.join(":")
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
    self.new(
      version = "#{VERSION}",
      font = "DroidSansMono#{nerd ? " Nerd Font" : ""}",
      bold = false,
      left_separator = "#{ice || flames || powerline || circle ? "" : nerd ? "" : "|"}",
      right_separator = "#{ice || flames || powerline || circle ? "" : nerd ? "" : "|"}",
      bg_color = "#{bg_color}",
      fg_color = "#{fg_color}",
      position = "top",
      font_size = "9",
      steps_colors = powerline || circle ? ["0:95:0", "65:95:0", "95:0:0"] : ["0:165:0", "255:165:0", "255:0:0"],
      refreshes = "10",
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
      "# thresholds colors for gauges\n" + \
      "# there are three colors in R:G:B format\n" + \
      "steps_colors=#{@steps_colors.join(" ")}\n" + \
      "# time between two bar refreshes in seconds\n" + \
      "refreshes=#{@refreshes}\n" + \
      "# lefts are gauges aligned to the left\n" + \
      "# named like this left::<name of source>\n" + \
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
    lefts = conf.select { |x, y| x.match /left::.*/ }.map { |x, y| Left.from_s x.sub(/.*::/, ""), y }
    rights = conf.select { |x, y| x.match /right::.*/ }.map { |x, y| Right.from_s x.sub(/.*::/, ""), y }
    self.new(
      version = conf["version"],
      font = conf["font"],
      bold = conf["bold"] == "true",
      left_separator = conf["left_separator"].to_s,
      right_separator = conf["right_separator"].to_s,
      bg_color = conf["bg_color"].to_s,
      fg_color = conf["fg_color"].to_s,
      position = conf["position"].to_s,
      font_size = conf["font_size"].to_s,
      steps_colors = conf["steps_colors"].split(" "),
      refreshes = conf["refreshes"].to_s,
      lefts,
      rights
      )
  end

  def self.load
    self.from_s(File.read(self.path))
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
      "-b                bold (default to false)\n" \
      "-ls <separator>   left separator\n" \
      "-rs <separator>   right separator\n" \
      "-bg <color>       bg color\n" \
      "-fg <color>       fg color\n" \
      "-p  <position>    bar position (available: #{Theme.positions})\n" \
      "-fs <size>        font size\n" \
      "-sc <colors>      steps colors\n"
      "-r <seconds>      time between two bar refreshes\n"
  end

  def with_args!(args)
    with_arg(args, "-f") { |x| @font  = x }
    with_flag(args, "-b") { @bold = true }
    with_arg(args, "-ls") { |x| @left_separator  = x }
    with_arg(args, "-rs") { |x| @right_separator  = x }
    with_arg(args, "-bg") { |x| @bg_color  = x }
    with_arg(args, "-fg") { |x| @fg_color  = x }
    with_arg(args, "-p") { |x| @position  = x }
    with_arg(args, "-fs") { |x| @font_size  = x }
    with_arg(args, "-sc") { |x| @steps_colors  = x.split(" ") }
    with_arg(args, "-r") { |x| @refreshes  = x }
    self
  end
end

