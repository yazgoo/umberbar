extern crate umberbar;

use std::time::Duration;
use umberbar::{Conf, umberbar, WidgetPosition, Sources, Logos, ThemedWidgets, Palette, Widget};
use std::collections::HashMap;

#[tokio::main]
async fn main() {
    let palette = Palette::grey_blue_cold_winter();
    let mut widgets : HashMap<WidgetPosition, Vec<Widget>> = HashMap::new();
    let lefts = ThemedWidgets::slash(
                WidgetPosition::Left, vec![
                (Sources::battery(), Logos::battery()),
                (Sources::cpu(), Logos::cpu()),
                (Sources::cpu_temp(), Logos::cpu_temp()),
                (Sources::window(), Logos::window()),
                ], &palette);
    let rights = ThemedWidgets::slash(
                    WidgetPosition::Right, vec![
                    (Sources::date(), Logos::date()),
                    (Sources::memory(), Logos::memory()),
                    ], &palette);
    widgets.insert(lefts.0, lefts.1);
    widgets.insert(rights.0, rights.1);
    umberbar(Conf {
        font: "DroidSansMono Nerd Font".to_string(),
        font_size: 8,
        terminal_width: 178,
        refresh_time: Duration::from_secs(2),
        widgets: widgets,
    }).run().await;
}
