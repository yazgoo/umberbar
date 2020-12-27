#!/usr/bin/env bash

colorize() {
  first_color=$2
  first_step=$3
  second_color=$4
  second_step=$5
  third_color=$6
  if [ $1 -lt  $first_step ]
  then
    color=$first_color
  elif [ $1 -lt $second_step ]
  then
    color=$second_color
  else
    color=$third_color
  fi
  printf "\033[38:2:%sm%3d\033[m\n" "$color" "$1"
}

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

battery_logo() {
  if [ $1 -lt 10 ]
  then
    echo ""
  elif [ $1 -lt 20 ]
  then 
    echo ""
  elif [ $1 -lt 30 ]
  then 
    echo ""
  elif [ $1 -lt 40 ]
  then 
    echo ""
  elif [ $1 -lt 50 ]
  then
  echo ""
  elif [ $1 -lt 60 ]
  then 
    echo ""
  elif [ $1 -lt 70 ]
  then
    echo ""
  elif [ $1 -lt 80 ]
  then
    echo ""
  elif [ $1 -lt 90 ]
  then
    echo ""
  else
    echo ""
  fi
}

volume_logo() {
  if [ $volume -eq 0 ]
  then
    echo "🔇"
  else
    echo "🔊"
  fi
}

grey() {
  printf "\033[38:2:%sm%s\033[m\n" "150:150:150" "$1"
}

gauge() {
  colors="0:165:0 "$4" 255:165:0 "$5" 255:0:0"
  if [ -n "$6" ]
  then
    colors=$(echo $colors|tr ' ' '\n'|tac|tr '\n' ' ')
  fi
  echo -ne "$(grey "$1")$(colorize "$2" $colors)$(grey "$3") $sep "
}

draw_date() {
  date_str_len=${#date}
  date_cursor_pos=$(( COLUMNS - date_str_len - 2 ))
  echo -ne "\033[0;${date_cursor_pos}H"
  echo -ne $(grey " ")
  echo -ne "$date"
}

draw_line() {
  echo -ne "\033[0;0H"
  sep=$(grey "")
  blogo=$(battery_logo $battery_capacity)
  vlogo=$(volume_logo $volume)
  gauge "$blogo" "$battery_capacity"         "%"  20 50 reverse_colors
  gauge " "     "$cpu"                      "%"  40 70
  gauge ""      "$temp"                     "°C" 40 70
  gauge " "     "$mem"                      "%"  30 70
  gauge "$vlogo" "$volume"                   "%"  60 120
  echo -ne "$(grey " ") ${windowname}${additional_spaces}"
  draw_date
}

battery_path=/sys/class/power_supply/cw2015-battery
if [ ! -e "$battery_path" ]
then
  battery_path=/sys/class/power_supply/BAT0
fi

tput civis
last_idle_total="0 0"
while true
do
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
  draw_line
  sleep 10
done
