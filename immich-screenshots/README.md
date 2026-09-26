# immich-screenshots

Uploads new screenshots to Immich as they appear: desktop screenshots into
"PC Screenshots" (archived), game screenshots into one album per game
(Minecraft: one album, instance as tag). The original file path goes into the
asset description.

- `config.toml` – the sources (path pattern → album, tags, archive, backfill); format is documented at the top.
- `immich-screenshots` – the daemon (Python, stdlib only; needs `immich-go`).
- `immich-screenshots.service` – systemd user unit.
- `.env` – `IMMICH_SERVER_URL=…` and `IMMICH_API_KEY=…`, not in git, mode 600.
- State: `~/.local/state/immich-screenshots/state.json` (uploaded files, sources already seen).

## Use

```sh
systemctl --user restart immich-screenshots   # after editing config.toml
journalctl --user -u immich-screenshots -f    # log
./immich-screenshots --once --dry-run          # show what would be uploaded now
```

A new source picks up its existing files on start, unless `backfill = false`.
To re-upload a file, remove its entry from the state file.

## API key permissions

immich-go (upload, albums, tags) plus `bulk-upload-check`, reading and updating
assets for the description and archiving. If a permission is missing, the log
shows the HTTP 403 body naming it.
