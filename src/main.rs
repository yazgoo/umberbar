extern crate umberbar;

use std::time::Duration;
use umberbar::{Conf, umberbar, WidgetPosition, Sources, Logos, ThemedWidgets, Palette};

#[tokio::main]
async fn main() {
    let palette = Palette::grey_blue_cold_winter();
    umberbar(Conf {
        font: "DroidSansMono Nerd Font".to_string(),
        font_size: 8,
        terminal_width: 178,
        refresh_time: Duration::from_secs(2),
        widgets: [
            ThemedWidgets::slash(
                WidgetPosition::Left, vec![
                (Sources::battery(), Logos::battery()),
                (Sources::cpu(), Logos::cpu()),
                (Sources::cpu_temp(), Logos::cpu_temp()),
                (Sources::window(), Logos::window()),
                ], &palette),
                ThemedWidgets::slash(
                    WidgetPosition::Right, vec![
                    (Sources::date(), Logos::date()),
                    (Sources::memory(), Logos::memory()),
                    ], &palette)
        ].iter().cloned().collect(),
    }).run().await;
}
