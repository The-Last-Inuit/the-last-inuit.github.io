+++
title = "rustamp | core + (Iced || RatatUI)"
date = 2025-11-12
+++

We are going with both UI engines. I like the idea of maintaining both.

So, we need to restructure our mp3 player:

```bash
rustamp/
  Cargo.toml
  crates/
    rustamp-core/
      Cargo.toml
      src/
        lib.rs
        model.rs
        audio.rs
        persist.rs
        util.rs
        engine.rs
    rustamp-iced/
      Cargo.toml
      src/
        main.rs
        app.rs
        dialogs.rs
        ui.rs
    rustamp-tui/
      Cargo.toml
      src/
        main.rs
        ui.rs

```

This will allows us to have two binaries:

```bash
$ cargo run -p rustamp-iced
$ cargo run -p rustamp-tui
```

Let's begin.

First, let us have a diff root `Cargo.toml`:

```toml
[workspace]
resolver = "2"
members = [
  "crates/rustamp-core",
  "crates/rustamp-iced",
  "crates/rustamp-tui",
]
```

rustamp-core: `Cargo.toml`:

```toml
[package]
name = "rustamp-core"
version = "0.1.0"
edition = "2024"

[dependencies]
rodio = { version = "0.21.1", features = ["playback"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
directories = "6"
```

rustamp-iced: `Cargo.toml`:

```toml
[package]
name = "rustamp-iced"
version = "0.1.0"
edition = "2024"

[dependencies]
rustamp-core = { path = "../rustamp-core"}
iced = { version = "0.14", features = ["tokio", "wgpu"] }
rfd = { version = "0.16.0", features = ["tokio"] }
```

rustamp-tui: `Cargo.toml`:

```toml
[package]
name = "rustamp-tui"
version = "0.1.0"
edition = "2024"

[dependencies]
rustamp-core = { path = "../rustamp-core" }
ratatui = "0.29"
crossterm = "0.28.1"
```

Most of the changes or rather additions are on the `rustamp-tui` part:

```rust
// main.rs
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind, KeyModifiers},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{Terminal, backend::CrosstermBackend};
use rustamp_core::{Command, Effect, Engine, persist};
use std::io;
use std::path::PathBuf;
use std::time::{Duration, Instant};

mod ui;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Mode {
    Normal,
    Command,
}

struct UiState {
    mode: Mode,
    cmdline: String,
}

fn main() -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let res = run(&mut terminal);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    res
}

fn run(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    let mut engine = Engine::new();
    let mut state = UiState {
        mode: Mode::Normal,
        cmdline: String::new(),
    };

    let tick_rate = Duration::from_millis(120);
    let mut last_tick = Instant::now();

    loop {
        terminal.draw(|f| ui::draw(f, &engine.machine, state.mode, &state.cmdline))?;

        let timeout = tick_rate.saturating_sub(last_tick.elapsed());
        if event::poll(timeout)? {
            if let Event::Key(k) = event::read()? {
                if k.kind != KeyEventKind::Press {
                    continue;
                }

                if state.mode == Mode::Normal && matches!(k.code, KeyCode::Char('q')) {
                    break;
                }

                match state.mode {
                    Mode::Normal => handle_normal_key(&mut engine, &mut state, k.code, k.modifiers),
                    Mode::Command => handle_command_key(&mut engine, &mut state, k.code),
                }
            }
        }

        if last_tick.elapsed() >= tick_rate {
            step(&mut engine, Command::Tick);
            last_tick = Instant::now();
        }
    }

    Ok(())
}

fn handle_effect(engine: &mut Engine, eff: Effect) {
    if let Effect::Persist(snap) = eff {
        if let Err(e) = persist::save(snap) {
            engine.machine.error = Some(format!("Failed to save state: {e}"));
        }
    }
}

fn handle_normal_key(engine: &mut Engine, state: &mut UiState, code: KeyCode, mods: KeyModifiers) {
    if mods.contains(KeyModifiers::CONTROL) || mods.contains(KeyModifiers::ALT) {
        return;
    }

    match code {
        KeyCode::Char(':') => {
            state.mode = Mode::Command;
            state.cmdline.clear();
        }

        KeyCode::Char('o') => {
            state.mode = Mode::Command;
            state.cmdline = "open ".into();
        }
        KeyCode::Char('a') => {
            state.mode = Mode::Command;
            state.cmdline = "add ".into();
        }

        KeyCode::Char('p') => {
            step(engine, Command::PlaySelected);
        }
        KeyCode::Char('i') => {
            step(engine, Command::Pause);
        }
        KeyCode::Char('s') => {
            step(engine, Command::Stop);
        }

        KeyCode::Char('l') => {
            step(engine, Command::LoadSelected);
        }
        KeyCode::Char('d') => {
            step(engine, Command::RemoveSelected);
        }

        KeyCode::Char('n') => {
            step(engine, Command::NextTrack);
        }
        KeyCode::Char('b') => {
            step(engine, Command::PrevTrack);
        }

        KeyCode::Char('j') => {
            step(engine, Command::SelectDown);
        }
        KeyCode::Char('k') => {
            step(engine, Command::SelectUp);
        }
        KeyCode::Char('g') => {
            step(engine, Command::SelectTop);
        }
        KeyCode::Char('G') => {
            step(engine, Command::SelectBottom);
        }

        KeyCode::Char('J') => {
            step(engine, Command::MoveSelectedDown);
        }
        KeyCode::Char('K') => {
            step(engine, Command::MoveSelectedUp);
        }

        KeyCode::Char('t') => {
            step(engine, Command::TogglePlayPause);
        }

        _ => {}
    }
}

fn handle_command_key(engine: &mut Engine, state: &mut UiState, code: KeyCode) {
    match code {
        KeyCode::Esc => {
            state.mode = Mode::Normal;
            state.cmdline.clear();
        }
        KeyCode::Enter => {
            let cmds = parse_cmdline(&state.cmdline);
            for cmd in cmds {
                step(engine, cmd);
            }
            state.mode = Mode::Normal;
            state.cmdline.clear();
        }
        KeyCode::Backspace => {
            state.cmdline.pop();
        }
        KeyCode::Char(c) => {
            state.cmdline.push(c);
        }
        _ => {}
    }
}

fn parse_cmdline(s: &str) -> Vec<Command> {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        return vec![];
    }

    let parts: Vec<&str> = trimmed.split_whitespace().collect();
    let head = parts[0];

    match head {
        "open" => {
            let path = parts.get(1).map(|p| PathBuf::from(*p));
            vec![Command::FilePicked(path)]
        }
        "add" => {
            let ps: Vec<PathBuf> = parts.iter().skip(1).map(|p| PathBuf::from(*p)).collect();
            vec![Command::FilesPicked(ps)]
        }
        "play" => vec![Command::PlaySelected],
        "pause" => vec![Command::Pause],
        "stop" => vec![Command::Stop],
        "next" => vec![Command::NextTrack],
        "prev" => vec![Command::PrevTrack],
        "load" => vec![Command::LoadSelected],
        "del" | "rm" => vec![Command::RemoveSelected],
        _ => {
            vec![Command::FilePicked(Some(PathBuf::from(trimmed)))]
        }
    }
}

fn step(engine: &mut Engine, cmd: Command) {
    let eff = engine.apply(cmd);
    handle_effect(engine, eff);
}

```

And now, the important part, the `engine.rs`, UI agnostic:

```rust
use crate::audio::AudioEngine;
use crate::model::{Machine, Status, Track};
use crate::persist;

use std::path::PathBuf;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub enum Command {
    Tick,
    OpenFileRequest,
    AddFilesRequest,
    FilePicked(Option<PathBuf>),
    FilesPicked(Vec<PathBuf>),

    Play,
    Pause,
    Stop,
    TogglePlayPause,

    Select(usize),
    SelectDown,
    SelectUp,
    SelectTop,
    SelectBottom,

    MoveSelectedDown,
    MoveSelectedUp,

    LoadSelected,
    PlaySelected,

    RemoveSelected,
    NextTrack,
    PrevTrack,
}

#[derive(Debug, Clone)]
pub enum EngineEffect {
    None,
    RequestOpenFile,
    RequestAddFiles,
    Persisted(Result<(), String>),
}

pub struct Engine {
    pub machine: Machine,
    audio: Option<AudioEngine>,
}

impl Default for Engine {
    fn default() -> Self {
        let mut machine = Machine::default();
        let audio = match AudioEngine::new() {
            Ok(a) => Some(a),
            Err(e) => {
                machine.error = Some(e);
                None
            }
        };

        if let Ok(Some(saved)) = persist::load_opt() {
            machine.volume = saved.volume.clamp(0.0, 1.0);

            machine.playlist = saved
                .playlist
                .into_iter()
                .filter(|p| std::fs::metadata(p).is_ok())
                .map(Track::from_path)
                .collect();

            let len = machine.playlist.len();
            machine.selected = saved.selected.filter(|&i| i < len);
            machine.now_playing = saved.now_playing.filter(|&i| i < len);
        }

        Self { machine, audio }
    }
}

impl Engine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn apply(&mut self, cmd: Command) -> EngineEffect {
        match cmd {
            Command::Tick => self.on_tick(),

            Command::OpenFileRequest => EngineEffect::RequestOpenFile,
            Command::AddFilesRequest => EngineEffect::RequestAddFiles,

            Command::FilePicked(p) => { self.on_file_picked(p); EngineEffect::None }
            Command::FilesPicked(ps) => { self.on_files_picked(ps); EngineEffect::None }

            Command::Select(i) => { self.select(i); EngineEffect::None }
            Command::SelectDown => { self.select_down(); EngineEffect::None }
            Command::SelectUp => { self.select_up(); EngineEffect::None }
            Command::SelectTop => { self.select_top(); EngineEffect::None }
            Command::SelectBottom => { self.select_bottom(); EngineEffect::None }

            Command::MoveSelectedDown => { self.move_selected_down(); EngineEffect::None }
            Command::MoveSelectedUp => { self.move_selected_up(); EngineEffect::None }

            Command::LoadSelected => { self.load_selected(); EngineEffect::None }
            Command::PlaySelected => { self.load_selected(); self.play(); EngineEffect::None }

            Command::Play => { self.play(); EngineEffect::None }
            Command::Pause => { self.pause(); EngineEffect::None }
            Command::Stop => { self.stop(); EngineEffect::None }
            Command::TogglePlayPause => {
                match self.machine.status {
                    Status::Playing => self.pause(),
                    Status::Paused | Status::Stopped => self.play(),
                }
                EngineEffect::None
            }

            Command::NextTrack => { self.next_track(); EngineEffect::None }
            Command::PrevTrack => { self.prev_track(); EngineEffect::None }
            Command::RemoveSelected => { self.remove_selected(); EngineEffect::None }
        }
    }

    fn on_tick(&mut self) -> EngineEffect {
        if let Some(audio) = self.audio.as_ref() {
            if self.machine.seeking_secs.is_none() {
                self.machine.position = audio.position();
            }

            if self.machine.status == Status::Playing && audio.is_finished() {
                if let Some(i) = self.machine.now_playing {
                    let next = i + 1;
                    if next < self.machine.playlist.len() {
                        self.machine.selected = Some(next);
                        self.load_selected();
                        self.play();
                        return EngineEffect::None;
                    }
                }
                self.machine.status = Status::Stopped;
            }
        }

        if let Some(t0) = self.machine.dirty_since {
            if t0.elapsed() >= Duration::from_millis(500) {
                self.machine.dirty_since = None;
                let snap = self.snapshot_state_for_persist();
                return EngineEffect::Persisted(persist::save(snap));
            }
        }

        EngineEffect::None
    }

    fn snapshot_state_for_persist(&self) -> persist::PersistedState {
        persist::PersistedState {
            playlist: self.machine.playlist.iter().filter_map(|t| t.path.clone()).collect(),
            selected: self.machine.selected,
            now_playing: self.machine.now_playing,
            volume: self.machine.volume,
        }
    }

    fn select(&mut self, i: usize) {
        if i < self.machine.playlist.len() {
            self.machine.selected = Some(i);
            self.machine.touch();
        }
    }

    fn select_down(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 { return; }
        let cur = self.machine.selected.unwrap_or(0);
        self.machine.selected = Some((cur + 1).min(len - 1));
        self.machine.touch();
    }

    fn select_up(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 { return; }
        let cur = self.machine.selected.unwrap_or(0);
        self.machine.selected = Some(cur.saturating_sub(1));
        self.machine.touch();
    }

    fn select_top(&mut self) {
        if !self.machine.playlist.is_empty() {
            self.machine.selected = Some(0);
            self.machine.touch();
        }
    }

    fn select_bottom(&mut self) {
        let len = self.machine.playlist.len();
        if len > 0 {
            self.machine.selected = Some(len - 1);
            self.machine.touch();
        }
    }

    fn move_selected_down(&mut self) {
        let len = self.machine.playlist.len();
        if let Some(i) = self.machine.selected {
            if i + 1 < len {
                self.machine.playlist.swap(i, i + 1);
                self.machine.selected = Some(i + 1);
                self.machine.touch();
            }
        }
    }

    fn move_selected_up(&mut self) {
        if let Some(i) = self.machine.selected {
            if i > 0 {
                self.machine.playlist.swap(i, i - 1);
                self.machine.selected = Some(i - 1);
                self.machine.touch();
            }
        }
    }

    fn on_file_picked(&mut self, path_opt: Option<PathBuf>) {
        let Some(path) = path_opt else { return; };
        let Some(audio) = self.audio.as_mut() else {
            self.machine.error = Some("Audio engine not available.".into());
            return;
        };

        match audio.load_file_paused(path, self.machine.volume) {
            Ok(track) => {
                self.machine.track = Some(track);
                self.machine.position = Duration::ZERO;
                self.machine.status = Status::Stopped;
                self.machine.seeking_secs = None;
                self.machine.error = None;
            }
            Err(e) => self.machine.error = Some(e),
        }
    }

    fn on_files_picked(&mut self, paths: Vec<PathBuf>) {
        for p in paths {
            let already = self.machine.playlist.iter().any(|t| t.path.as_ref() == Some(&p));
            if !already {
                self.machine.playlist.push(Track::from_path(p));
                self.machine.touch();
            }
        }
    }

    fn load_selected(&mut self) {
        let Some(i) = self.machine.selected else { return; };
        self.machine.now_playing = Some(i);

        let Some(path) = self.machine.playlist.get(i).and_then(|t| t.path.clone()) else {
            self.machine.error = Some("Selected track has no path.".into());
            return;
        };

        let Some(audio) = self.audio.as_mut() else {
            self.machine.error = Some("Audio engine not available.".into());
            return;
        };

        match audio.load_file_paused(path, self.machine.volume) {
            Ok(track) => {
                self.machine.track = Some(track.clone());
                self.machine.position = Duration::ZERO;
                self.machine.status = Status::Stopped;
                self.machine.seeking_secs = None;
                self.machine.error = None;

                if let Some(d) = track.duration {
                    if let Some(item) = self.machine.playlist.get_mut(i) {
                        item.duration = Some(d);
                    }
                }
            }
            Err(e) => self.machine.error = Some(e),
        }
    }

    fn play(&mut self) {
        if self.machine.track.is_some() {
            if let Some(audio) = self.audio.as_ref() {
                audio.play();
                self.machine.status = Status::Playing;
            }
        }
    }

    fn pause(&mut self) {
        if let Some(audio) = self.audio.as_ref() {
            audio.pause();
            self.machine.status = Status::Paused;
        }
    }

    fn stop(&mut self) {
        if let Some(audio) = self.audio.as_mut() {
            audio.stop();
        }
        self.machine.status = Status::Stopped;
        self.machine.position = Duration::ZERO;
        self.machine.seeking_secs = None;
    }

    fn next_track(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 { return; }

        let cur = self.machine.now_playing.or(self.machine.selected).unwrap_or(0);
        let next = (cur + 1).min(len - 1);
        if next == cur {
            self.stop();
            return;
        }
        self.machine.selected = Some(next);
        self.load_selected();
        self.play();
    }

    fn prev_track(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 { return; }

        let cur = self.machine.now_playing.or(self.machine.selected).unwrap_or(0);
        let prev = cur.saturating_sub(1);
        self.machine.selected = Some(prev);
        self.load_selected();
        self.play();
    }

    fn remove_selected(&mut self) {
        if let Some(i) = self.machine.selected {
            if i < self.machine.playlist.len() {
                self.machine.playlist.remove(i);
                self.machine.touch();
                if self.machine.playlist.is_empty() {
                    self.machine.selected = None;
                } else if i >= self.machine.playlist.len() {
                    self.machine.selected = Some(self.machine.playlist.len() - 1);
                }
            }
        }
    }
}

// ui.rs
use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout},
    style::{Modifier, Style, Stylize},
    text::{Line, Span},
    widgets::{Block, Borders, LineGauge, List, ListItem, Paragraph},
};
use rustamp_core::util::format_mmss;
use rustamp_core::{Machine, Status};

use super::Mode;

pub fn draw(f: &mut Frame, machine: &Machine, mode: Mode, cmdline: &str) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(
            [
                Constraint::Length(3),
                Constraint::Min(1),
                Constraint::Length(1),
            ]
            .as_ref(),
        )
        .split(f.area());

    let title = machine
        .track
        .as_ref()
        .map(|t| t.title.as_str())
        .unwrap_or("-");
    let status = match machine.status {
        Status::Stopped => "stopped",
        Status::Playing => "playing",
        Status::Paused => "paused",
    };

    let dur = machine.track.as_ref().and_then(|t| t.duration);
    let dur_secs = dur.map(|d| d.as_secs_f64()).unwrap_or(0.0);
    let pos_secs = machine.position.as_secs_f64().min(dur_secs.max(0.0001));
    let ratio = if dur_secs > 0.0 {
        (pos_secs / dur_secs).clamp(0.0, 1.0)
    } else {
        0.0
    };

    let left = format_mmss(machine.position);
    let right = dur.map(format_mmss).unwrap_or_else(|| "--:--".into());

    let player = Paragraph::new(vec![
        Line::from(vec![Span::raw(title)]),
        Line::from(vec![
            Span::raw(status),
            Span::raw("  "),
            Span::raw(left),
            Span::raw(" / "),
            Span::raw(right),
        ]),
    ])
    .block(Block::default().borders(Borders::ALL).title("player"));

    f.render_widget(player, chunks[0]);

    let gauge = LineGauge::default()
        .block(Block::bordered().title("Progress"))
        .filled_style(Style::new().white().on_black().bold())
        .ratio(ratio);

    let inner = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1)].as_ref())
        .split(chunks[1]);

    f.render_widget(gauge, inner[0]);

    let items: Vec<ListItem> = machine
        .playlist
        .iter()
        .enumerate()
        .map(|(i, t)| {
            let sel = machine.selected == Some(i);
            let marker = if sel { ">" } else { " " };
            let line = Line::from(vec![Span::raw(format!("{marker} ")), Span::raw(&t.title)]);
            ListItem::new(line)
        })
        .collect();

    let mut list = List::new(items).block(Block::default().borders(Borders::ALL).title("playlist"));

    list = list.highlight_style(Style::default().add_modifier(Modifier::BOLD));

    f.render_widget(list, inner[1]);

    let footer_left = match mode {
        Mode::Normal => "keys: : cmd  q quit  o/a cmd-open/add",
        Mode::Command => "cmd:",
    };

    let footer_mid = match mode {
        Mode::Normal => "".to_string(),
        Mode::Command => format!(":{cmdline}"),
    };

    let footer_right = if let Some(e) = machine.error.as_ref() {
        format!("err: {e}")
    } else {
        "".to_string()
    };

    let footer = Line::from(vec![
        Span::raw(footer_left),
        Span::raw("  "),
        Span::raw(footer_mid),
        Span::raw("  "),
        Span::raw(footer_right),
    ]);

    f.render_widget(Paragraph::new(footer), chunks[2]);
}
```

And as for changes, `engine.rs` becomes the core, leaving all the UI to each respective UI libraries:

```rust
use crate::audio::AudioEngine;
use crate::model::{Machine, Status, Track};
use crate::persist;

use std::path::PathBuf;
use std::time::Duration;

#[derive(Debug, Clone)]
pub enum Command {
    Tick,

    FilePicked(Option<PathBuf>),
    FilesPicked(Vec<PathBuf>),

    Select(usize),
    SelectDown,
    SelectUp,
    SelectTop,
    SelectBottom,

    MoveSelectedDown,
    MoveSelectedUp,

    LoadSelected,
    PlaySelected,

    RemoveSelected,

    NextTrack,
    PrevTrack,

    Play,
    Pause,
    Stop,
    TogglePlayPause,
}

#[derive(Debug, Clone)]
pub enum Effect {
    None,
    Persist(persist::PersistedState),
}

pub struct Engine {
    pub machine: Machine,
    audio: Option<AudioEngine>,
}

impl Default for Engine {
    fn default() -> Self {
        let mut machine = Machine::default();

        let audio = match AudioEngine::new() {
            Ok(a) => Some(a),
            Err(e) => {
                machine.error = Some(e);
                None
            }
        };

        if let Ok(Some(saved)) = persist::load_opt() {
            machine.volume = saved.volume.clamp(0.0, 1.0);

            machine.playlist = saved
                .playlist
                .into_iter()
                .filter(|p| std::fs::metadata(p).is_ok())
                .map(Track::from_path)
                .collect();

            let len = machine.playlist.len();
            machine.selected = saved.selected.filter(|&i| i < len);
            machine.now_playing = saved.now_playing.filter(|&i| i < len);
        }

        Self { machine, audio }
    }
}

impl Engine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn apply(&mut self, cmd: Command) -> Effect {
        match cmd {
            Command::Tick => self.tick(),

            Command::FilePicked(p) => {
                self.on_file_picked(p);
                Effect::None
            }
            Command::FilesPicked(ps) => {
                self.on_files_picked(ps);
                Effect::None
            }

            Command::Select(i) => {
                if i < self.machine.playlist.len() {
                    self.machine.selected = Some(i);
                    self.machine.touch();
                }
                Effect::None
            }
            Command::SelectDown => {
                let len = self.machine.playlist.len();
                if len > 0 {
                    let cur = self.machine.selected.unwrap_or(0);
                    self.machine.selected = Some((cur + 1).min(len - 1));
                    self.machine.touch();
                }
                Effect::None
            }
            Command::SelectUp => {
                let len = self.machine.playlist.len();
                if len > 0 {
                    let cur = self.machine.selected.unwrap_or(0);
                    self.machine.selected = Some(cur.saturating_sub(1));
                    self.machine.touch();
                }
                Effect::None
            }
            Command::SelectTop => {
                if !self.machine.playlist.is_empty() {
                    self.machine.selected = Some(0);
                    self.machine.touch();
                }
                Effect::None
            }
            Command::SelectBottom => {
                let len = self.machine.playlist.len();
                if len > 0 {
                    self.machine.selected = Some(len - 1);
                    self.machine.touch();
                }
                Effect::None
            }

            Command::MoveSelectedDown => {
                let len = self.machine.playlist.len();
                if let Some(i) = self.machine.selected {
                    if i + 1 < len {
                        self.machine.playlist.swap(i, i + 1);
                        self.machine.selected = Some(i + 1);
                        self.machine.touch();
                    }
                }
                Effect::None
            }
            Command::MoveSelectedUp => {
                if let Some(i) = self.machine.selected {
                    if i > 0 {
                        self.machine.playlist.swap(i, i - 1);
                        self.machine.selected = Some(i - 1);
                        self.machine.touch();
                    }
                }
                Effect::None
            }

            Command::LoadSelected => {
                self.load_selected();
                Effect::None
            }
            Command::PlaySelected => {
                self.load_selected();
                self.play();
                Effect::None
            }

            Command::RemoveSelected => {
                self.remove_selected();
                Effect::None
            }

            Command::NextTrack => {
                self.next_track();
                Effect::None
            }
            Command::PrevTrack => {
                self.prev_track();
                Effect::None
            }

            Command::Play => {
                self.play();
                Effect::None
            }
            Command::Pause => {
                self.pause();
                Effect::None
            }
            Command::Stop => {
                self.stop();
                Effect::None
            }
            Command::TogglePlayPause => {
                match self.machine.status {
                    Status::Playing => self.pause(),
                    Status::Paused | Status::Stopped => self.play(),
                }
                Effect::None
            }
        }
    }

    fn snapshot(&self) -> persist::PersistedState {
        persist::PersistedState {
            playlist: self
                .machine
                .playlist
                .iter()
                .filter_map(|t| t.path.clone())
                .collect(),
            selected: self.machine.selected,
            now_playing: self.machine.now_playing,
            volume: self.machine.volume,
        }
    }

    fn tick(&mut self) -> Effect {
        if let Some(audio) = self.audio.as_ref() {
            if self.machine.seeking_secs.is_none() {
                self.machine.position = audio.position();
            }

            if self.machine.status == Status::Playing && audio.is_finished() {
                if let Some(i) = self.machine.now_playing {
                    let next = i + 1;
                    if next < self.machine.playlist.len() {
                        self.machine.selected = Some(next);
                        self.load_selected();
                        self.play();
                    } else {
                        self.machine.status = Status::Stopped;
                    }
                } else {
                    self.machine.status = Status::Stopped;
                }
            }
        }

        if let Some(t0) = self.machine.dirty_since {
            if t0.elapsed() >= Duration::from_millis(500) {
                self.machine.dirty_since = None;
                return Effect::Persist(self.snapshot());
            }
        }

        Effect::None
    }

    fn on_file_picked(&mut self, path_opt: Option<PathBuf>) {
        let Some(path) = path_opt else {
            return;
        };
        let Some(audio) = self.audio.as_mut() else {
            self.machine.error = Some("Audio engine not available.".into());
            return;
        };

        match audio.load_file_paused(path, self.machine.volume) {
            Ok(track) => {
                self.machine.track = Some(track);
                self.machine.position = Duration::ZERO;
                self.machine.status = Status::Stopped;
                self.machine.seeking_secs = None;
                self.machine.error = None;
            }
            Err(e) => self.machine.error = Some(e),
        }
    }

    fn on_files_picked(&mut self, paths: Vec<PathBuf>) {
        for p in paths {
            let already = self
                .machine
                .playlist
                .iter()
                .any(|t| t.path.as_ref() == Some(&p));
            if !already {
                self.machine.playlist.push(Track::from_path(p));
                self.machine.touch();
            }
        }
    }

    fn load_selected(&mut self) {
        let Some(i) = self.machine.selected else {
            return;
        };
        self.machine.now_playing = Some(i);

        let Some(path) = self.machine.playlist.get(i).and_then(|t| t.path.clone()) else {
            self.machine.error = Some("Selected track has no path.".into());
            return;
        };

        let Some(audio) = self.audio.as_mut() else {
            self.machine.error = Some("Audio engine not available.".into());
            return;
        };

        match audio.load_file_paused(path, self.machine.volume) {
            Ok(track) => {
                self.machine.track = Some(track.clone());
                self.machine.position = Duration::ZERO;
                self.machine.status = Status::Stopped;
                self.machine.seeking_secs = None;
                self.machine.error = None;

                if let Some(d) = track.duration {
                    if let Some(item) = self.machine.playlist.get_mut(i) {
                        item.duration = Some(d);
                    }
                }
            }
            Err(e) => self.machine.error = Some(e),
        }
    }

    fn play(&mut self) {
        if self.machine.track.is_some() {
            if let Some(audio) = self.audio.as_ref() {
                audio.play();
                self.machine.status = Status::Playing;
            }
        }
    }

    fn pause(&mut self) {
        if let Some(audio) = self.audio.as_ref() {
            audio.pause();
            self.machine.status = Status::Paused;
        }
    }

    fn stop(&mut self) {
        if let Some(audio) = self.audio.as_mut() {
            audio.stop();
        }
        self.machine.status = Status::Stopped;
        self.machine.position = Duration::ZERO;
        self.machine.seeking_secs = None;
    }

    fn next_track(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 {
            return;
        }

        let cur = self
            .machine
            .now_playing
            .or(self.machine.selected)
            .unwrap_or(0);
        let next = (cur + 1).min(len - 1);
        if next == cur {
            self.stop();
            return;
        }
        self.machine.selected = Some(next);
        self.load_selected();
        self.play();
    }

    fn prev_track(&mut self) {
        let len = self.machine.playlist.len();
        if len == 0 {
            return;
        }

        let cur = self
            .machine
            .now_playing
            .or(self.machine.selected)
            .unwrap_or(0);
        let prev = cur.saturating_sub(1);
        self.machine.selected = Some(prev);
        self.load_selected();
        self.play();
    }

    fn remove_selected(&mut self) {
        if let Some(i) = self.machine.selected {
            if i < self.machine.playlist.len() {
                self.machine.playlist.remove(i);
                self.machine.touch();

                if self.machine.playlist.is_empty() {
                    self.machine.selected = None;
                } else if i >= self.machine.playlist.len() {
                    self.machine.selected = Some(self.machine.playlist.len() - 1);
                }
            }
        }
    }
}
```

It's still buggy but loving the new separation of reponsabilities to cover two 
different UI engines.

Next

* Fix bugs
* Better aesthetics without losing the minimalism of it
* Add more decoders, maybe?
