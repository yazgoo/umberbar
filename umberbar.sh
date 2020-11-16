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

while true
do
  battery_capacity=$(colorize $(cat /sys/class/power_supply/cw2015-battery/capacity) 255:0:0 20 255:165:0 50 0:165:0)
  battery_status=$(cat /sys/class/power_supply/cw2015-battery/status)
  date=$(date)
  temp=$(colorize $[ $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ] 0:165:0 40 255:165:0 70 255:0:0)
  windowname=$(xdotool getwindowfocus getwindowname)
  mem=$(colorize $(extractmem) 0:165:0 30 255:165:0 70 255:0:0)
  clear
  echo -n "${battery_capacity}% $battery_status | $date | ${temp}C | mem ${mem}% | ${windowname:0:40}"
  sleep 10
done
