# human-machine-bridge

Bridges between human and machine on the workstation (CachyOS, GNOME 50 on
Wayland, German keyboard layout): keyboard shortcuts, mouse buttons, text
snippets, dictation.

## Language

- Write this file, other docs and all code comments in English.
- Content may be German (e.g. Espanso snippets, typed text) – the user is German.
- Reply to the user in German.

## What this repo is for

1. **Collection:** Only things the human deliberately decided for how to operate
   this machine. Nothing that programs generate or manage themselves (caches,
   history, automatically written state, untouched default configs), and never
   secrets.
2. **Workspace:** AI chats about this machine are opened here, including for
   one-off system changes. Those get done but are **not** stored here. When in
   doubt, ask whether something belongs in the repo.

## Layout

- `AGENTS.md` – read natively by Claude Code, Codex and OpenCode; no `CLAUDE.md` needed.
- `install.sh` – symlinks the expected config paths into this repo. Idempotent;
  existing files are moved to `*.bak-<date>`, never deleted.
- `espanso/` → `~/.config/espanso` – text snippets.
- `keymapper/keymapper.conf` → `~/.config/keymapper.conf` – keys/mouse buttons → actions.
- `scripts/` – helper scripts called from keymapper (referenced via `$HOME/Git/human-machine-bridge/scripts/…`):
  `debounce` (generic, for mouse-button actions), `minecraft-perspective`,
  `clipboard-qr` (also symlinked to `~/.local/bin/`), `teamspeak-action`,
  `teamspeak-hotkey`, `teamspeak3-hotkey`, `handy-teamspeak`.
- `scripts/transcribe` – transcribes media files with Handy; symlinked to
  `~/bin/transcribe`.
- `run-or-raise/shortcuts.conf` → `~/.config/run-or-raise/shortcuts.conf` – launch/raise
  apps by shortcut (GNOME-specific window layer).
- `immich-screenshots/` → `~/.config/immich-screenshots` – screenshot upload to Immich;
  its `.service` → `~/.config/systemd/user/`. Details in its `README.md`.

## Components and their quirks

### keymapper
- `keymapperd` runs as a system service (root) and grabs keyboard, mouse and
  virtual input devices exclusively; `keymapper -u` starts via
  `/etc/xdg/autostart/keymapper.desktop` and reloads the config on change.
- Per-application rules (`[class = "…"]`) need the bundled GNOME extension
  `keymapper@houmain.github.com` on Wayland (enabled; active after next login).
- Characters missing from the German layout are typed via Ctrl+Shift+U hex
  input – works in GTK/IBus apps, not everywhere.
- Emergency stop if input misbehaves: `sudo systemctl stop keymapperd`.
- keymapper grabs devices before libinput, so libinput's switch debouncing does
  not apply to mapped mouse buttons. Actions on mouse buttons that must not
  fire twice go through `scripts/debounce`.
- Debugging: `keymapper -u -v` logs every executed command.
- All custom shortcuts live here; GNOME custom shortcuts (media-keys) are
  intentionally empty. GNOME's own window shortcuts (Alt+Tab, Super+M, …) stay
  in GNOME.
- Programs launched by keymapper inherit its environment. When restarting
  `keymapper`/`handy` from a terminal inside another app (e.g. T3 Code, which
  sets `LD_LIBRARY_PATH` and `ELECTRON_RUN_AS_NODE`), use the clean session env:
  `mapfile -t E < <(systemctl --user show-environment); env -i "${E[@]}" setsid -f keymapper -u`

### Espanso (espanso-wayland, EVDEV)
- Only picks up keyboards present when it starts. If a new input device appears
  later, it stops receiving input → restart Espanso.
- Affected: restarts of `keymapperd` and of ckb-next (the Corsair K95 recreates
  its virtual keyboard `ckb1: … vKB`). For ckb-next this is handled by
  `/etc/udev/rules.d/99-espanso-ckb.rules` →
  `~/.config/systemd/user/espanso-restart.service` (both not in the repo yet).
- Telltale in `~/.cache/espanso/espanso.log`: `removing from epoll`.

### Handy (dictation, `handy-bin`)
- Model: Parakeet TDT 0.6B V3. Settings are managed by the app itself
  (`~/.local/share/com.pais.handy/settings_store.json`, not in the repo).
- Shortcuts (keymapper): mouse button 5 (debounced) and Ctrl+Space →
  `scripts/handy-teamspeak` → `handy --toggle-transcription` (on GNOME Wayland,
  Handy cannot grab global shortcuts itself).
- Text output: `ydotool` (user service `ydotool.service`), pasting via Ctrl+V –
  direct typing breaks umlauts and y/z on the German layout. `wtype` does not
  work on GNOME.
- Overlay stays off: on GNOME Wayland it steals focus and the text lands in the
  wrong window (known Handy issue; not caused by the "Steal My Focus Window"
  extension – tested).
- The tray icon needs the extension `appindicatorsupport@rgcjonas.gmail.com`.

### TeamSpeak 6
- The client is installed manually at `~/.local/bin/teamspeak-client`; its
  desktop launcher forces X11. GNOME Wayland still does not deliver its hotkeys
  while another Wayland application is focused.
- F14/F15/F16 (Corsair G-keys) trigger microphone mute, speaker mute and AFK
  through `scripts/teamspeak-action`. For TS6 it uses `scripts/teamspeak-hotkey`
  and TeamSpeak Remote Apps. The three
  virtual keys `hmb.mic`, `hmb.sound`, `hmb.afk` are bound in TeamSpeak itself.
- The Remote Apps API key is stored at
  `~/.config/human-machine-bridge/teamspeak-remote-api-key` (mode 0600), outside
  this repo. Reauthorize with `scripts/teamspeak-hotkey authorize` if needed.
- `scripts/handy-teamspeak` makes mouse button 5 and Ctrl+Space temporarily mute
  TeamSpeak while Handy transcribes, then restores the prior microphone state.
  It also mutes the TeamSpeak recording stream in PipeWire as a safeguard.
- TeamSpeak 3 uses its bundled ClientQuery plugin through
  `scripts/teamspeak3-hotkey` for the same F14/F15/F16 actions. The plugin reads
  its API key from `~/.ts3client/clientquery.ini`, outside this repo; keep that
  file mode 0600. ClientQuery selects the active TS3 server connection. The
  Handy wrapper protects both TS6 and TS3 microphone states and recording
  streams when they are connected.

### Run or Raise (GNOME extension `run-or-raise@edvard.cz`)
- Launches an app, raises it, or cycles its windows – runs inside GNOME Shell,
  so it reacts instantly. Config reloads automatically.
- Super+S is used for YouTube Music; GNOME's default `toggle-quick-settings`
  (Super+S) was cleared for that.
- The Corsair G-keys send F14–F19 (set in ckb-next). Careful: xkb turns F13–F18
  into the keysyms XF86Tools/XF86Launch5–9, so GNOME/Run or Raise cannot bind
  them as `F14`…`F18` (keymapper sees the raw keys and is unaffected). F19 stays F19.
- Super+T raises T3 Code, F19 opens Files (Nautilus); Super+Enter (keymapper)
  always opens a new terminal. keymapper turns the Run or Raise keys into a
  short tap: a held key
  auto-repeats, Run or Raise then cycles windows continuously and GNOME Shell
  stalls (frozen mouse pointer). Do the same for other Run or Raise keys if held.

### immich-screenshots
- `.env` holds the Immich API key: it stays unread by agents and out of git.
  Check the key's effect through the service log instead.
- Game sources leave the Immich archive state untouched; only sources with
  `archive = true` archive, and only the assets of the files just uploaded.
- immich-go 0.32 uploads, creates albums and sets tags, but cannot set a
  description or archive, and skips album and tags for assets already on the
  server ("server has duplicate"). The script covers all three via the Immich API.
- Immich's metadata extraction runs seconds after an upload and overwrites the
  description, so the script sets it only once the asset has its image size.
- GPU Screen Recorder screenshots only reach the `~/Bilder/Screenshots` sources
  if its UI saves there (`screenshot.save_directory`, "save in game folder").

## GNOME Wayland limitations

- Applications cannot grab global shortcuts or change the mouse cursor outside
  their own windows.
- Reading, activating or moving windows only works through GNOME Shell
  extensions. Keep such parts separate so that switching to e.g. Hyprland only
  affects them.

## Communication

- When recommending tools or writing comparison tables, always link the tool
  name to its project page.
- Ask before changing third-party extensions, programs or system files.
