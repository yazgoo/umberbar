screen_width=$(xrandr |awk '$0 ~ "*" {print $1}'|cut -dx -f1)
font_size=10
screen_char_width=$(( screen_width / ( font_size - 2 ) ))
xterm -fa "DroidSansMono Nerd Font" -fs $font_size -fullscreen -geometry ${screen_char_width}x1+0+0 -bg black -fg white -class xscreensaver -e $(dirname $0)/umberbar.sh &
