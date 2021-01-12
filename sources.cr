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

class CustomSource < Source
  @name = ""
  @command = ""
  def initialize(name, command)
    @name = name
    @command = command
  end
  def name
    @name
  end
  def command
    @command
  end

  def unit
    ""
  end

  def get
    `#{@command}`.chomp
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
    result = `xdotool getwindowfocus getwindowpid getwindowname 2>/dev/null`.chomp.split("\n")
    if result.size == 2
      pid, name = result
      "#{File.read("/proc/#{pid}/comm").chomp} - #{name}"
    else
      ""
    end
  end
end

