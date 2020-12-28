#!/usr/bin/env bash

# <extraction>

extractmeminfo() {
  echo "$2" | grep "^$1:" | sed -E 's/.* ([0-9]+).*/\1/'
}

extractmem() {
  meminfo=$(cat /proc/meminfo)
  memtotal=$(extractmeminfo MemTotal "$meminfo")
  memfree=$(extractmeminfo MemFree "$meminfo")
  cached=$(extractmeminfo Cached "$meminfo")
  sreclaimable=$(extractmeminfo SReclaimable "$meminfo")
  shmem=$(extractmeminfo Shmem "$meminfo")
  echo $(( ( $memtotal - $memfree - $cached - $sreclaimable + $shmem ) * 100 / $memtotal ))
}

cpu_idle_total() {
  values=$(cat /proc/stat | head -1 | sed 's/^cpu *//')
  total=0
  idle=0
  i=0
  for value in $values
  do
    if [ $i == 3 ]
    then
      idle=$value
    fi
    total=$(( total + value ))
    i=$(( i + 1 ))
  done
  echo $idle $total
}

second() {
  echo $2
}

first() {
  echo $1
}

cpu_percent() {
  idle=$(first $1)
  total=$(second $1)
  last_idle=$(first $2)
  last_total=$(second $2)
  echo $(( 100 - ( (100 * (idle - last_idle) / (total - last_total))) )) 
}

extract() {
  if [ -z "$last_idle_total" ]
  then
    last_idle_total="0 0"
  fi
  battery_path=/sys/class/power_supply/cw2015-battery
  if [ ! -e "$battery_path" ]
  then
    battery_path=/sys/class/power_supply/BAT0
  fi

  battery_capacity=$(cat $battery_path/capacity)
  battery_status=$(cat $battery_path/status)
  if [ $battery_status = "Full" ]
  then
    battery_capacity=100
  fi
  date=$(date | sed -E 's/:[0-9]{2} .*//')
  temp=$[ $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ]
  idle_total=$(cpu_idle_total)
  cpu=$(cpu_percent "$idle_total" "$last_idle_total")
  last_idle_total="$idle_total"
  previous_windowname_len=${#windowname}
  windowname=$(xdotool getwindowfocus getwindowname)
  windowname_len=${#windowname}
  delta_window_name=$(( previous_windowname_len - windowname_len ))
  if [ $delta_window_name -gt 0 ]
  then
    additional_spaces=$(print "%${delta_window_name}s" "")
  else
    additional_spaces=""
  fi
  mem=$(extractmem)
  mixer_out=$(amixer sget Master)
  volume=$(echo "$mixer_out"|grep -oE '[0-9]+%'|sed 's/%//'|head -1)
  if echo "$mixer_out" | grep '\[off\]' >/dev/null
  then
    volume=0
  fi
}

# </extraction>

# <presentation>

colorize() {
  printf "\033[38:2:%sm%$1\033[m\n" "$2" "$3"
}

colorize_with_steps() {
  if [ $1 -lt  $3 ]
  then
    color=$2
  elif [ $1 -lt $5 ]
  then
    color=$4
  else
    color=$6
  fi
  colorize 3d "$color" "$1"
}


grey() {
  colorize s 150:150:150 "$1"
}

gauge() {
  colors="0:165:0 "$4" 255:165:0 "$5" 255:0:0"
  if [ "$4" -gt "$5" ]
  then
    colors=$(echo $colors|tr ' ' '\n'|tac|tr '\n' ' ')
  fi
  echo -ne "$(grey "$1")$(colorize_with_steps "$2" $colors)$(grey "$3") $sep "
}

draw_date() {
  date_str_len=${#date}
  date_cursor_pos=$(( COLUMNS - date_str_len - 2 ))
  echo -ne "\033[0;${date_cursor_pos}H"
  echo -ne $(grey " ")
  echo -ne "$date"
}

draw() {
  tput civis
  echo -ne "\033[0;0H"
  sep=$(grey "")
  blogo=$(echo -e ":\n1:\n2:\n3:\n4:\n5:\n6:\n7:\n8:\n9:\n10:" | grep -E "^$(echo "$battery_capacity" | sed 's/.$//'):" | cut -d: -f2)
  vlogo=$([ $volume -eq 0 ] && echo "🔇" || echo "🔊")
  gauge "$blogo" "$battery_capacity"         "%"  50 20
  gauge " "     "$cpu"                      "%"  40 70
  gauge ""      "$temp"                     "°C" 40 70
  gauge " "     "$mem"                      "%"  30 70
  gauge "$vlogo" "$volume"                   "%"  60 120
  echo -ne "$(grey " ") ${windowname}${additional_spaces}"
  draw_date
}

with_xterm() {
  screen_width=$(xrandr |awk '$0 ~ "*" {print $1}'|cut -dx -f1)
  font_size=9
  screen_char_width=$(( screen_width / ( font_size - 2 ) ))
  xterm -fa "DroidSansMono Nerd Font" -fs $font_size -fullscreen -geometry ${screen_char_width}x1+0+0 -bg black -fg white -class xscreensaver -e "$0" &
}

# </presentation>

run() {
  while true
  do
    extract
    draw
    sleep 10
  done
}

if [ "$1" = "xterm" ]
then
  with_xterm
else
  run
fi
