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
    ["black", "white", "black-no-nerd", "white-no-nerd"]
  end

  def self.positions
    ["top", "bottom"]
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
    @position = Theme.positions.index(position).nil? ? Theme.positions[0] : position
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

  def self.from_name(name)
    black = name.match /.*black.*/
    bg_color, fg_color = black ? ["black", "grey"] : ["white", "black"]
    nerd = name.match(/.*no-nerd.*/).nil?
    self.new(
      version = "#{VERSION}",
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

  def self.args_help
    puts "Theme overriding:\n\n" \
      "-f  <font>        font\n" \
      "-ls <separator>   left separator\n" \
      "-rs <separator>   right separator\n" \
      "-bg <color>       bg color\n" \
      "-fg <color>       fg color\n" \
      "-p  <position>    bar position (available: #{Theme.positions})\n" \
      "-fs <size>        font size\n" \
      "-sc <colors>      steps colors\n"
  end

  def with_args!(args)
    with_arg(args, "-f") { |x| @font  = x }
    with_arg(args, "-ls") { |x| @left_separator  = x }
    with_arg(args, "-rs") { |x| @right_separator  = x }
    with_arg(args, "-bg") { |x| @bg_color  = x }
    with_arg(args, "-fg") { |x| @fg_color  = x }
    with_arg(args, "-p") { |x| @position  = x }
    with_arg(args, "-fs") { |x| @font_size  = x }
    with_arg(args, "-sc") { |x| @steps_colors  = x.split(" ") }
    self
  end
end

