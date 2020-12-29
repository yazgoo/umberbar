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
  echo $(( ( memtotal - memfree - cached - sreclaimable + shmem ) * 100 / memtotal ))
}

cpu_idle_total() {
  values=$(head -1 < /proc/stat | sed 's/^cpu *//')
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
}

compute_cpu() {
  if [ -z "$last_idle" ]
  then
    last_idle=0
    last_total=0
  fi
  cpu_idle_total
  cpu=$(( 100 - ( (100 * (idle - last_idle) / (total - last_total))) ))
  last_idle="$idle"
  last_total="$total"
}

extract() {
  battery_path=/sys/class/power_supply/cw2015-battery
  if [ ! -e "$battery_path" ]
  then
    battery_path=/sys/class/power_supply/BAT0
  fi

  battery_capacity=$(cat $battery_path/capacity)
  battery_status=$(cat $battery_path/status)
  if [ "$battery_status" = "Full" ]
  then
    battery_capacity=100
  fi
  date=$(date | sed -E 's/:[0-9]{2} .*//')
  temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
  compute_cpu
  previous_windowname_len=${#windowname}
  windowinfo=$(xdotool getwindowfocus getwindowname getwindowpid)
  windowname=$(echo "$windowinfo"|head -1)
  windowpid=$(echo "$windowinfo"|tail -1)
  windowcommand=$(strings "/proc/$windowpid/cmdline" | head -1)
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
  printf "\\033[38:2:%sm%$1\\033[m\\n" "$2" "$3"
}

colorize_with_steps() {
  if [ "$1" -lt  "${colors[1]}" ]
  then
    color="${colors[0]}"
  elif [ "$1" -lt "${colors[3]}" ]
  then
    color="${colors[2]}"
  else
    color="${colors[4]}"
  fi
  colorize 3d "$color" "$1"
}


grey() {
  colorize s ${normal_color} "$1"
}

left() {
  echo -ne "$(grey "$1")$2 $(grey "$separator_left") "
}

gauge() {
  colors_str="0:165:0
$3
255:165:0
$4
255:0:0"
  if [ "$3" -gt "$4" ]
  then
    colors_str=$(echo -e "$colors_str"|tac)
  fi
  mapfile -t colors <<< "$colors_str"
  echo "$(colorize_with_steps "$1")$(grey "$2")"
}

right() {
  s="$(grey " $separator_right $1 ")$2 "
  # shellcheck disable=SC2001
  s_without_ansi=$(echo "$s" | sed "s/$(echo -e "\\e")[^m]*m//g")
  str_len=${#s_without_ansi}
  echo -ne "\\033[${str_len}D"
  echo -ne "$s"
  echo -ne "\\033[${str_len}D"
}

leftmost() {
  echo -ne "\\033[0;0H"
}

rightmost() {
  echo -ne "\\033[0;$((COLUMNS ))H"
}

with_xterm() {
  screen_width=$(xrandr |awk '$0 ~ "*" {print $1}'|cut -dx -f1)
  screen_char_width=$(( screen_width / ( font_size - 2 ) ))
  xterm -fa "$font" -fs $font_size -fullscreen -geometry ${screen_char_width}x1+0+0 -bg $bg_color -fg $fg_color -class xscreensaver -e "$0 $*" &
}

# </presentation>

run() {
  tput civis
  while true
  do
    extract
    draw
    sleep 5
  done
}

if [ -n "$2" ]
then
  source "$2"
else
  source "$(dirname $0)/black.theme"
fi
if [ "$1" = "xterm" ]
then
  with_xterm shell "$2"
else
  run
fi
