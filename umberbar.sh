#!/usr/bin/env bash
tput civis

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
    
  printf "\033[38:2:%sm%s\033[m\n" "$color" "$1"
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

cols=$(( $COLUMNS / 3 ))
_2cols=$(( $cols* 2 )) 

battery_path=/sys/class/power_supply/cw2015-battery
if [ ! -e "$battery_path" ]
then
  battery_path=/sys/class/power_supply/BAT0
fi

last_idle_total="0 0"
while true
do
  battery_capacity=$(colorize $(cat $battery_path/capacity) 255:0:0 20 255:165:0 50 0:165:0)
  battery_status=$(cat $battery_path/status)
  if [ $battery_status = "Discharging" ]
  then
    if [ -e $battery_path/time_to_empty_now ]
    then
      time_to_empty=$(cat $battery_path/time_to_empty_now)
      battery_status="($(( $time_to_empty / 60 )):$(( $time_to_empty - ($time_to_empty / 60 * 60) )))"
    fi
  fi
  date=$(date)
  temp=$(colorize $[ $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ] 0:165:0 40 255:165:0 70 255:0:0)
  idle_total=$(cpu_idle_total)
  cpu=$(colorize $(cpu_percent "$idle_total" "$last_idle_total") 0:165:0 40 255:165:0 70 255:0:0)
  last_idle_total="$idle_total"
  windowname=$(xdotool getwindowfocus getwindowname)
  mem=$(colorize $(extractmem) 0:165:0 30 255:165:0 70 255:0:0)
  echo -ne "\033[0;0H"
  printf "%-${_2cols}.${_2cols}s" "Batt: ${battery_capacity}% $battery_status | Cpu: ${cpu}% | Temp: ${temp}C | Mem: ${mem}% | ${windowname}"
  echo -ne "\033[0;${_2cols}H"
  printf "%${cols}s" "$date"
  sleep 10
done
