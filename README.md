# umberbar

:ram: minimalistic xmobar inspired status bar, in terminal. 

![black theme](black.png)

![white theme](white-no-nerd.png)

# prerequisites 

- for black and white theme, you need [nerdfonts](https://www.nerdfonts.com/) installed
- you need xterm installed
- you need either crystal or ruby installed

# configuration

by default, umberbar will create `~/.config/umberbar.conf`.
there are other examples of configurations in `themes/` folder

# building / running it (crystal)

```
crystal build umberbar.cr
```

```
./umberbar xterm
```

# running it (ruby)

```
./umberbar.rb xterm
```
