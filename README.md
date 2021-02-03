# umberbar 🐏  

minimalistic xmobar inspired status bar, in a terminal emulator. 

![UmberBar Screenshot](screenshot.jpg)

# rust implementation

This project was previously written in crystal, it is being ported to rust.

Crystal version allowed me to have a clear view of the features this project needs and the ones it does not.

It is based on the same concepts as umberwm.

All versions >= 0.7 are rust based.

## design goals and features (rust implementation)

- [x] kiss: where possible build upon existing crates, use alacritty for rendering
- [x] configuration as code (like umberwm)
- [x] support theming (as code), user defined palette
- [x] single file (~500 LoC) -- may be subject to change
- [ ] loads of themes

## requirements

You need alacritty installed and in your path (this project will run alacritty)

You also need nerd fonts for logos and most themes to work.

## using it

umberbar is used/configured in rust, here is how to use it:

1. install rust and cargo https://doc.rust-lang.org/cargo/getting-started/installation.html
2. clone template project (__:warning: it is a different repository__): `git clone https://github.com/yazgoo/myumberbar`
3. edit src/main.rs (see comments for more details)
4. run `cargo build`, binary is available in target/debug/myumerbar
