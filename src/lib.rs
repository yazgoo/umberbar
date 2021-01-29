use std::env;
use std::time::Duration;
use std::collections::HashMap;
use std::process::Command;
use tokio::time::sleep;
use systemstat::{System, Platform, saturating_sub_bytes};
use std::io::Write;
use std::fs::File;

type Logo = fn(&Value) -> String;

#[derive(Debug, Clone)]
pub enum Value {
    S(String),
    I(u8),
}

#[derive(Debug, Clone)]
pub struct Source {
    pub unit: Option<String>,
    pub get: fn() -> Value,
}

pub struct Sources {
}

macro_rules! i_source {
    ($x:expr, $y:expr) =>  {
    Source {
      unit: Some($x.to_string()),
      get: || Value::I($y(System::new()) as u8)
    }
  }
}

macro_rules! s_source {
    ($x:expr, $y:expr) =>  {
    Source {
      unit: Some($x.to_string()),
      get: || Value::S($y),
    }
  }
}

impl Sources {

  pub fn battery() -> Source {
      i_source!("%", |s: System| s.battery_life().map_or(0.0, |x| (x.remaining_capacity * 100.0)))
  }

  pub fn cpu() -> Source {
      i_source!("%", |_| 0.0) /* TODO implement */
  }

  pub fn cpu_temp() -> Source {
      i_source!("°C", |s: System| s.cpu_temp().unwrap_or(0.0))
  }

  pub fn memory() -> Source {
      i_source!("%", |s: System| s.memory().map_or(0.0, |mem| (saturating_sub_bytes(mem.total, mem.free).as_u64()  / mem.total.as_u64()) as f32))
  }

  pub fn date() -> Source {
      s_source!("", { let mut s = Command::new("sh")
          .arg("-c")
              .arg("date | sed -E 's/:[0-9]{2} .*//'").output().map_or("".to_string(), |o| String::from_utf8(o.stdout).unwrap_or("".to_string())); s.pop(); s})
  }

  pub fn window() -> Source {
      s_source!("", { let mut s = Command::new("sh")
          .arg("-c")
              .arg("xdotool getwindowfocus getwindowname 2>/dev/null").output().map_or("".to_string(), 
                  |o| String::from_utf8(o.stdout).unwrap_or("".to_string())); s.pop(); s})
  }
}

pub struct Logos {
}

macro_rules! i_logo {
    ($x:expr) =>  {
        |v| match v {
            Value::S(_) => "",
            Value::I(i) => $x(i)
        }.to_string()
  }
}

impl Logos {

    pub fn battery() -> Logo {
        i_logo!(|i| ["", "", "", "", "", "", "", "", "", "", ""].get((i/10) as usize).unwrap_or(&""))
    }

    pub fn cpu() -> Logo {
        |_| " ".to_string()
    }

    pub fn cpu_temp() -> Logo {
        |_| " ".to_string()
    }

    pub fn memory() -> Logo {
        |_| " ".to_string()
    }

    pub fn date() -> Logo {
        |_| " ".to_string()
    }

    pub fn window() -> Logo {
        |_| " ".to_string()
    }

}

type Color = u32;

#[derive(Clone)]
pub enum ColoredStringItem {
    S(String),
    BgColor(Color),
    FgColor(Color),
    StopFg,
    StopBg,
}

#[derive(Clone)]
pub struct ColoredString {
    string: Vec<ColoredStringItem>,
}

impl ColoredString {

    pub fn new() -> ColoredString {
        ColoredString {
            string: vec![],
        }
    }

    pub fn bg(&mut self, color: Color) -> &mut ColoredString {
        self.string.push(ColoredStringItem::BgColor(color));
        self
    }

    pub fn fg(&mut self, color: Color) -> &mut ColoredString {
        self.string.push(ColoredStringItem::FgColor(color));
        self
    }

    pub fn s(&mut self, s: &str) -> &mut ColoredString {
        self.string.push(ColoredStringItem::S(s.to_string()));
        self
    }

    pub fn ebg(&mut self) -> &mut ColoredString {
        self.string.push(ColoredStringItem::StopBg);
        self
    }

    pub fn efg(&mut self) -> &mut ColoredString {
        self.string.push(ColoredStringItem::StopFg);
        self
    }

    fn htc(color: Color) -> String {
        let b = color & 0xff;
        let g = color >> 1 & 0xff;
        let r = color >> 2 & 0xff;
        format!("{};{};{}", r, g, b)
    }

    pub fn to_string(&self) -> String {
        self.string.clone().into_iter().map ( |item|
            match item {
                ColoredStringItem::S(s) => s,
                ColoredStringItem::BgColor(c) => format!("\x1b[48;2;{}m", ColoredString::htc(c)),
                ColoredStringItem::FgColor(c) => format!("\x1b[38;2;{}m", ColoredString::htc(c)),
                ColoredStringItem::StopBg => "\x1b[49m".to_string(),
                ColoredStringItem::StopFg => "\x1b[39m".to_string(),
            }
        ).collect::<Vec<String>>().join("")
    }

    pub fn len(&self) -> usize {
        self.string.clone().into_iter().map ( |item|
            match item {
                ColoredStringItem::S(s) => s.chars().count(),
                _ => 0,
            }
        ).fold(0, |a, b| a + b)
    }

}

pub struct ThemedWidgets {
}

impl ThemedWidgets {

    pub fn simple(widget_position: WidgetPosition, sources_logos: Vec<(Source, Logo)>) -> (WidgetPosition, Vec<Widget>) {
        let left = widget_position == WidgetPosition::Left;
        (widget_position,
         sources_logos.into_iter().map( |source_logo|
             Widget {
                 source: source_logo.0,
                 prefix: ColoredString::new().bg(0).fg(0xfffff).s(" ").clone(),
                 suffix: ColoredString::new().s(" ").ebg().efg().s(" ").clone(),
                 logo: source_logo.1,
             }).collect())
    }
}

#[derive(Clone)]
pub struct Widget {
    pub source: Source,
    pub prefix: ColoredString,
    pub suffix: ColoredString,
    pub logo: Logo,
}

struct Ansi {
}

impl Ansi {

    fn hide_cursor() {
        print!("\x1b[?25l");
    }

    fn move_back(n: usize) {
        print!("\x1b[{}D", n);
    }

    fn move_to(line: usize, col: usize) {
        print!("\x1b[{};{}H", line, col);
    }
}

#[derive(Debug, Clone, PartialEq, std::cmp::Eq, Hash)]
pub enum WidgetPosition {
    Left,
    Right
}

impl Widget {
    pub async fn draw(&self, widget_position: &WidgetPosition) {
        let value = (self.source.get)();
        let logo = (self.logo)(&value);
        let value_s = match value {
            Value::S(s) => s,
            Value::I(i) => i.to_string()
        };
        let s = format!("{}{} {}{}{}", self.prefix.to_string(), logo, value_s, self.source.unit.clone().unwrap_or(String::from("")), self.suffix.to_string());
        if widget_position == &WidgetPosition::Left {
            print!("{}", s);
        } else {
            let len = format!("{} {}{}", logo, value_s, self.source.unit.clone().unwrap_or(String::from("")), ).chars().count() + self.prefix.len() + self.suffix.len();
            Ansi::move_back(len);
            print!("{}", s);
            Ansi::move_back(len);
        }
    }
}

pub struct Conf {
    pub font: String,
    pub font_size: u8,
    pub terminal_width: u16,
    pub refresh_time: Duration,
    pub widgets: HashMap<WidgetPosition, Vec<Widget>>,
}

pub struct UmberBar {
    pub conf: Conf
}

impl UmberBar {

    pub async fn draw_at(widget_position: &WidgetPosition, widgets: &Vec<Widget>) {
        for widget in widgets {
            widget.draw(&widget_position).await
        }
    }

    pub async fn draw(&mut self) {
        let left = WidgetPosition::Left;
        let right = WidgetPosition::Right;
        Ansi::move_to(0, 0);
        UmberBar::draw_at(&left, self.conf.widgets.get(&left).unwrap_or(&vec![])).await;
        Ansi::move_to(0, self.conf.terminal_width as usize);
        UmberBar::draw_at(&right, self.conf.widgets.get(&right).unwrap_or(&vec![])).await;
        let _ = std::io::stdout().flush();
    }

    fn is_child_process() -> bool {
        match env::var("within_umberbar") {
            Ok(_) => true,
            Err(_) => false,
        }

    }

    async fn run_inside_terminal(&mut self) {
        Ansi::hide_cursor();
        loop {
            self.draw().await;
            sleep(self.conf.refresh_time).await;
        }
    }

    fn run_terminal(&mut self) {
          let output = format!("font:\n  family: {}\n  size: {}\nbackground_opacity: 0", self.conf.font, self.conf.font_size);
          let alacritty_conf_path = "/tmp/alacritty-umberbar-rs.yml";
          let mut ofile = File::create(alacritty_conf_path)
              .expect("unable to create file");
        ofile.write_all(output.as_bytes())
            .expect("unable to write");
        match std::env::current_exe() {
            Ok(cmd) => {
                let _ = Command::new("alacritty")
                    .env("within_umberbar", "true")
                    .arg("--config-file")
                    .arg(alacritty_conf_path)
                    .arg("--position")
                    .arg("0")
                    .arg("0")
                    .arg("--dimensions")
                    .arg(format!("{}", self.conf.terminal_width))
                    .arg("1")
                    .arg("--class")
                    .arg("xscreensaver")
                    .arg("--command")
                    .arg(cmd).output();
                }
            Err(e) => { print!("{}", e); }
        }
    }

    pub async fn run(&mut self) {
        if UmberBar::is_child_process() {
            self.run_inside_terminal().await
        } else {
            self.run_terminal()
        }
    }
}

pub fn umberbar(conf: Conf) -> UmberBar {
    UmberBar {
        conf: conf
    }
}
