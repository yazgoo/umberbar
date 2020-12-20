screen_width=$(xrandr |awk '$0 ~ "*" {print $1}'|cut -dx -f1)
screen_char_width=$(( screen_width / 8 ))
xterm -fa "DroidSansMono Nerd Font" -fs 10 -fullscreen -geometry ${screen_char_width}x1+0+0 -bg black -fg white -class xscreensaver -e $(dirname $0)/umberbar.sh &
