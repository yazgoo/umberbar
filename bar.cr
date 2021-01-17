require "./utils"
require "./logos"
require "./sources"
require "./drawing_items"
require "./theme"

class Bar

  def left_gravity(sym)
  end
  @sources = { "bat" => Source.new }
  @embedded = false
  @theme = Theme.new(VERSION, "", "", -1, 0, false, "", "", "", "", "", "", [""], "10",
                     [CustomSource.new("dat", "date")],
                     [Left.new("left", [0, 1], ".*:left", "", "")],
                     [Right.new("right", [0, 1], ".*:right", "", "")])

  def initialize(theme, embedded)
    @sources = { "bat" => Battery.new, "cpu" => Cpu.new, "tem" => CpuTemperatureSource.new, "win" => WindowCommand.new, "vol" => Volume.new, "mem" => Memory.new }
    @theme = theme
    @embedded = embedded
  end

  def draw
    bar = ([LeftMost.new] + @theme.lefts + [RightMost.new] + @theme.rights)
    bar.each do |item|
      if @sources.has_key? item.source_name
        item.draw(@theme.left_separator, @theme.right_separator, @sources[item.source_name], @theme.steps_colors, @theme.bold)
      else 
        customs = @theme.custom_sources.select { |src| src.name == item.source_name}
        if customs.size > 0
          item.draw(@theme.left_separator, @theme.right_separator, customs[0], @theme.steps_colors, @theme.bold)
        else
          item.draw "", "", Source.new, [""], @theme.bold
        end
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

  def run(main_file)
    if !@embedded
      screen_dimension = screen_size
      xterm = @theme.term == "xterm"
      screen_char_width = @theme.terminal_width == -1 ? (screen_dimension[0] / ( @theme.font_size.to_i + @theme.font_spacing)).to_i + 1 : @theme.terminal_width
      font = is_ruby? ? @theme.font.split(" ").join("\\ ") : @theme.font
      y = @theme.position == "bottom" ? (screen_dimension[1] - @theme.font_size.to_i * 2) : 0
      additional_args = xterm ? ["-fa", font, "-fs", @theme.font_size, "-fullscreen", "-geometry", "#{screen_char_width}x1+0+#{y}", "-bg", @theme.bg_color, "-fg", @theme.fg_color, "-class", "xscreensaver", "-e"]
        : ["-fn", "xft:#{font}:pixelsize=#{@theme.font_size.to_i + 2}:antialias=true:hinting=true", "-geometry", "#{screen_char_width}x1+0+#{y}", "-bg", @theme.bg_color, "-depth", "32", "-bg", "rgba:3f00/3f00/3f00/0000", "-b", "0", "-name", "xscreensaver", "-e", "sh", "-c"]
      program_args = ARGV.map { |x| "'#{x}'" }.join(" ")
      if is_ruby?
        args = ([@theme.term] + additional_args + ["\"#{main_file} -e #{program_args}\""])
        Process.exec(args.join(" "))
      else
        args = additional_args + [PROGRAM_NAME + " -e #{program_args}"]
        Process.exec(@theme.term, args)
      end
    else
      print `clear`
      print `tput civis`
      while true
        @theme = Bar.get_conf if @theme.changed?
        draw
        sleep @theme.refreshes
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
    save_conf = ARGV.index("-s")
    Theme.select_load_or_save(theme_selected, theme, save_conf)
  end

  def self.help
    puts "Umberbar v#{VERSION}: status bar running on xterm"
    puts
    puts \
      "-h          display this help\n" \
      "-e          embed in a terminal\n" \
      "-t <theme>  load a specific theme (available: #{Theme.list})\n" \
      "-s          save current state in configuration in #{Theme.path}"
      "-q          do not run the bar"
    puts
    puts Theme.args_help
    exit
  end

  def self.main(main_file)
    self.help if ARGV.index("-h")
    embedded = !ARGV.index("-e").nil?
    conf = self.get_conf
    bar = Bar.new(
      conf,
      embedded
    )
    bar.run(main_file) if ARGV.index("-q").nil?
  end
end

