extern crate umberbar;

use std::time::Duration;
use umberbar::{Conf, umberbar, WidgetPosition, Sources, Logos, ThemedWidgets};

#[tokio::main]
async fn main() {
    umberbar(Conf {
        font: "DroidSansMono Nerd Font".to_string(),
        font_size: 8,
        terminal_width: 178,
        refresh_time: Duration::from_secs(2),
        widgets: [
            ThemedWidgets::simple(
                WidgetPosition::Left, vec![
                (Sources::battery(), Logos::battery()),
                (Sources::cpu(), Logos::cpu()),
                (Sources::cpu_temp(), Logos::cpu_temp()),
                (Sources::window(), Logos::window()),
                ]),
                ThemedWidgets::simple(
                    WidgetPosition::Right, vec![
                    (Sources::date(), Logos::date()),
                    (Sources::memory(), Logos::memory()),
                    ])
        ].iter().cloned().collect(),
    }).run().await;
}
