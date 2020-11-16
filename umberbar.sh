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

while true
do
  battery_capacity=$(colorize $(cat /sys/class/power_supply/cw2015-battery/capacity) 255:0:0 20 255:165:0 50 0:165:0)
  battery_status=$(cat /sys/class/power_supply/cw2015-battery/status)
  date=$(date)
  temp=$(colorize $[ $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ] 0:165:0 40 255:165:0 70 255:0:0)
  windowname=$(xdotool getwindowfocus getwindowname)
  clear
  echo -n "${battery_capacity}% $battery_status | $date | ${temp}C | $windowname"
  sleep 10
done
