use std::env;
use std::time::Duration;
use std::collections::HashMap;
use std::process::Command;
use tokio::time::sleep;
use systemstat::{System, Platform, saturating_sub_bytes, DelayedMeasurement, CPULoad};
use std::io::Write;
use std::fs::File;
use regex::Regex;

type Logo = fn(&Value) -> String;

pub enum Value {
    S(String),
    I(u8),
}

pub enum SourceData {
    U(usize),
    CPU(DelayedMeasurement<CPULoad>),
    Nothing
}

pub struct Source {
    pub unit: Option<String>,
    pub get: fn(&SourceData) -> (Value, SourceData),
    data: SourceData,
}

pub struct Sources {
}

macro_rules! i_source {
    ($x:expr, $y:expr) =>  {
    Source {
      unit: Some($x.to_string()),
      get: |_| (Value::I($y(System::new()) as u8), SourceData::Nothing),
      data: SourceData::Nothing,
    }
  }
}

macro_rules! s_source {
    ($x:expr, $y:expr) =>  {
    Source {
      unit: Some($x.to_string()),
      get: |_| (Value::S($y), SourceData::Nothing),
      data: SourceData::Nothing,
    }
  }
}

impl Sources {

  pub fn battery() -> Source {
      i_source!("%", |s: System| s.battery_life().map_or(0.0, |x| (
                  if x.remaining_capacity > 1.0 { 100.0 } else { x.remaining_capacity * 100.0})))
  }

  fn build_cpu(v: Value) -> (Value, SourceData) {
      match System::new().cpu_load_aggregate() {
          Ok(r) => (v, SourceData::CPU(r)),
          Err(_) => (v, SourceData::Nothing),
      }
  }

  pub fn cpu() -> Source {
      Source {
          unit: Some("%".to_string()),
          get: |d| {
              match d {
                  SourceData::CPU(cpu) =>  {
                      let cpu = cpu.done().unwrap();
                      let cpu = cpu.system + cpu.user;
                      Sources::build_cpu(Value::I((cpu * 100.0) as u8))
                  },
                  _ => Sources::build_cpu(Value::I(0)),
                  
              }
          },
          data: SourceData::Nothing,
      }
  }

  pub fn cpu_temp() -> Source {
      i_source!("°C", |s: System| s.cpu_temp().unwrap_or(0.0))
  }

  pub fn memory() -> Source {
      i_source!("%", |s: System| s.memory().map_or(0.0, |mem| (saturating_sub_bytes(mem.total, mem.free).as_u64()  * 100 / mem.total.as_u64()) as f32))
  }

  pub fn date() -> Source {
      s_source!("", { let mut s = Command::new("sh")
          .arg("-c")
              .arg("date | sed -E 's/:[0-9]{2} .*//'").output().map_or("".to_string(), |o| String::from_utf8(o.stdout).unwrap_or("".to_string())); s.pop(); s})
  }

  pub fn window(max_chars: usize) -> Source {
      Source {
          unit: None, 
          get: |d| { 
              let s = Command::new("sh")
                  .arg("-c")
                  .arg("xdotool getwindowfocus getwindowpid getwindowname 2>/dev/null").output().map_or("".to_string(), 
                      |o| String::from_utf8(o.stdout).unwrap_or("".to_string())); 
              let lines : Vec<&str> = s.split("\n").collect();
              if lines.len() >= 2 {
                  let mut comm = std::fs::read_to_string(format!("/proc/{}/comm", lines[0])).unwrap_or("".to_string());
                  comm.pop();
                  let s = format!("{} - {}", comm, lines[1]);
                  match d {
                      SourceData::U(max) =>
                          (Value::S(match s.char_indices().nth(*max) {
                              None => s,
                              Some((idx, _)) => (&s[..idx]).to_string(),
                          }), SourceData::U(*max)),
                      _ => (Value::S(s), SourceData::Nothing)
                  }
              }
              else {
                  match d {
                      SourceData::U(max) => (Value::S("".to_string()), SourceData::U(*max)),
                      _ => (Value::S("".to_string()), SourceData::Nothing),
                  }
              }
          },
          data: SourceData::U(max_chars),
      }
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

    fn website(s: &str) -> String {
        let browsers = "^(chrom|firefox|qutebrowser)";
        format!("{}.* {}.*", browsers, s)
    }

    fn terminals() -> String {
    "^(alacritty|termite|xterm)".to_string()
    }

    fn terminal(s: &str) -> String {
        format!("{}.* {}.*", Logos::terminals(), s)
    }

    pub fn window() -> Logo {
        |value| { 
            match value {
                Value::S(value) => {
                    let mut matches : HashMap<String, Regex> = HashMap::new();
                    macro_rules! nm {
                        ($x:expr, $y:expr) =>  {
                            matches.insert($x.to_string(), Regex::new($y).unwrap());
                        }
                    }
                    nm!(" ", &Logos::website("Stack Overflow"));
                    nm!(" ", &Logos::website("Facebook"));
                    nm!("暑", &Logos::website("Twitter"));
                    nm!(" ", &Logos::website("YouTube"));
                    nm!(" ", &Logos::website("reddit"));
                    nm!(" ", &Logos::website("Wikipedia"));
                    nm!(" ", &Logos::website("GitHub"));
                    nm!(" ", &Logos::website("WhatsApp"));
                    nm!(" ", "signal-desktop .*");
                    nm!(" ", &Logos::terminal("n?vim"));
                    nm!(" ", "^(mpv|mplayer).*");
                    nm!(" ", &(Logos::terminals() + ".*"));
                    nm!(" ", "^firefox.*");
                    nm!(" ", "^chrom.*");
                    nm!(" ", "^gimp.*");
                    matches.insert(" ".to_string(), Regex::new("^firefox.*").unwrap());
                    for (logo, reg) in &matches {
                        if reg.is_match(value) {
                            return logo.to_string();
                        }
                    }
                },
                Value::I(_) => {},
            }
            " ".to_string()
        }
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

    pub fn fg_bg(&mut self, colors: &(Color, Color)) -> &mut ColoredString {
        self.fg(colors.0).bg(colors.1)
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
        let g = (color >> 8) & 0xff;
        let r = (color >> 16) & 0xff;
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

pub type FgColorAndBgColor = (Color, Color);

pub struct Palette {
    _source: Option<String>,
    colors: Vec<FgColorAndBgColor>,
}

impl Palette {

    pub fn black() -> Palette {
        Palette {
            _source: None,
            colors: vec![(0xfffff, 0)]
        }
    }

    pub fn grey_blue_cold_winter() -> Palette {
        Palette {
            _source: Some("https://colorhunt.co/palette/252807".to_string()),
            colors: vec![
                (0,0xf6f5f5),
                (0,0xd3e0ea),
                (0xf6f5f5,0x1687a7),
                (0xd3e0ea,0x276678),
            ]
        }
    }

    pub fn red_pink_turquoise_spring() -> Palette {
        Palette {
            _source: Some("https://colorhunt.co/palette/2257091".to_string()),
            colors: vec![
                (0,0xef4f4f),
                (0,0xee9595),
                (0,0xffcda3),
                (0,0x74c7b8),
            ]
        }
    }

    pub fn get(&self, i: usize) -> &FgColorAndBgColor {
        self.colors.get(i % self.colors.len()).unwrap_or(&(0,0xff))
    }

}

pub struct ThemedWidgets {
}

impl ThemedWidgets {

    pub fn simple(widget_position: WidgetPosition, sources_logos: Vec<(Source, Logo)>, palette: &Palette) -> (WidgetPosition, Vec<Widget>) {
        (widget_position,
         sources_logos.into_iter().enumerate().map( |(i, source_logo)| {
             let fg_bg = palette.get(i);
             Widget {
                 source: source_logo.0,
                 prefix: ColoredString::new().fg_bg(fg_bg).s(" ").clone(),
                 suffix: ColoredString::new().s(" ").ebg().efg().s(" ").clone(),
                 logo: source_logo.1,
             }}).collect())
    }

    pub fn slash(widget_position: WidgetPosition, sources_logos: Vec<(Source, Logo)>, palette: &Palette) -> (WidgetPosition, Vec<Widget>) {
        (widget_position,
         sources_logos.into_iter().enumerate().map( |(i, source_logo)| {
             let fg_bg = palette.get(i);
             Widget {
                 source: source_logo.0,
                 prefix: ColoredString::new().fg(fg_bg.1).s(" ").fg_bg(fg_bg).s(" ").clone(),
                 suffix: ColoredString::new().s(" ").ebg().fg(fg_bg.1).s("").efg().s(" ").clone(),
                 logo: source_logo.1,
             }}).collect())
    }

    pub fn flames(widget_position: WidgetPosition, sources_logos: Vec<(Source, Logo)>, palette: &Palette) -> (WidgetPosition, Vec<Widget>) {
        (widget_position,
         sources_logos.into_iter().enumerate().map( |(i, source_logo)| {
             let fg_bg = palette.get(i);
             Widget {
                 source: source_logo.0,
                 prefix: ColoredString::new().fg(fg_bg.1).s(" ").fg_bg(fg_bg).s(" ").clone(),
                 suffix: ColoredString::new().s(" ").ebg().fg(fg_bg.1).s(" ").efg().s(" ").clone(),
                 logo: source_logo.1,
             }}).collect())
    }

    pub fn powerline(widget_position: WidgetPosition, sources_logos: Vec<(Source, Logo)>, palette: &Palette) -> (WidgetPosition, Vec<Widget>) {
        let sources_logos_len = sources_logos.len();
        let left = widget_position == WidgetPosition::Left;
        (widget_position,
         sources_logos.into_iter().enumerate().map( |(i, source_logo)| {
             let fg_bg = palette.get(i);
             let n_fg_bg = palette.get(i + 1);
             let prefix = if left {
                 ColoredString::new().fg_bg(fg_bg).s(" ").clone()
             } else {
                 let mut s = ColoredString::new();
                 if i + 1 < sources_logos_len {
                     s.bg(n_fg_bg.1);
                 }
                 s.fg(fg_bg.1).s("").fg_bg(fg_bg).s(" ").clone()
             };
             let suffix = if left { 
                 let mut s = ColoredString::new();
                 s.s(" ").ebg().fg(fg_bg.1);
                 if i + 1 < sources_logos_len { s.bg(n_fg_bg.1); };
                 s.s("").ebg().efg().clone()
             } else {
                 ColoredString::new().s(" ").ebg().efg().clone()
             };
             Widget {
                 source: source_logo.0,
                 prefix: prefix,
                 suffix: suffix,
                 logo: source_logo.1,
             }}).collect())
    }

}

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
    pub async fn draw(&mut self, widget_position: &WidgetPosition) {
        let value_data = (self.source.get)(&self.source.data);
        let value = value_data.0;
        self.source.data = value_data.1;
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

    pub async fn draw_at(widget_position: &WidgetPosition, widgets: &mut Vec<Widget>) {
        for widget in widgets {
            widget.draw(&widget_position).await
        }
    }

    pub async fn draw(&mut self) {
        let left = WidgetPosition::Left;
        let right = WidgetPosition::Right;
        Ansi::move_to(0, 0);
        print!("{}", " ".repeat(self.conf.terminal_width as usize));
        Ansi::move_to(0, 0);
        UmberBar::draw_at(&left, self.conf.widgets.get_mut(&left).unwrap_or(&mut vec![])).await;
        Ansi::move_to(0, self.conf.terminal_width as usize);
        UmberBar::draw_at(&right, self.conf.widgets.get_mut(&right).unwrap_or(&mut vec![])).await;
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
