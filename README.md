# umberbar 🐏  

minimalistic xmobar inspired status bar, in a terminal emulator. 

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

## using it

1. create a project with umberbar crate as a dependency.
2. create a main.rs like the one in this project.
