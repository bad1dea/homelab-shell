# homelab-shell — one prompt + MOTD for the whole fleet (Futurama edition)

A single shell experience for **every box** — servers, a Proxmox hypervisor,
and laptops/desktops. Pick a prompt theme once; it looks the same everywhere,
and each host wears its **Futurama character's colour** so you always know
where you are. SSH logins get a themed MOTD with live system status.

The whole point: **you don't hand-maintain dotfiles per box.** `~/.bashrc`
sources one file from this repo. A `git pull` is the update mechanism — edit
here, commit, push, `git pull` everywhere, done.

This is a standalone extract of the `shell/` directory from the private
[homelab](https://github.com/bad1dea/homelab) repo, so any machine (including
clients that don't have fleet SSH access or secrets) can install it with
nothing but this repo.

## Install on a new machine

```bash
git clone https://github.com/bad1dea/homelab-shell.git ~/.homelab-shell
~/.homelab-shell/install.sh --theme fancy   # also: simple|modern|minimal|classic|starship
# new shell, or:  source ~/.homelab-shell/shell-common.sh
```

**From your laptop, over SSH** (key auth, falls back to password):

```bash
./deploy-client.sh khuong@fry.local
./deploy-client.sh --motd always --art shuffle khuong@leela.local
```

```
./
  shell-common.sh        # THE entrypoint bashrc sources; picks theme, prints MOTD
  install.sh             # wire it into one account (idempotent)
  lib/
    futurama.sh          # per-host character → colour/glyph/quote map (source of truth)
    prompt-common.sh     # git status, exit-code, command-timing helpers
  themes/
    simple.sh fancy.sh modern.sh minimal.sh classic.sh   # pure-bash PS1 themes
    starship.toml        # the "use a maintained engine" option
  motd/
    motd.sh              # the message-of-the-day generator
    quotes.txt           # tagged in-character one-liners
    generate-art.sh      # mint figlet/lolcat banners (optional tools)
    render-portraits.sh  # (re)render portraits/*.png → art/*.ans via chafa
    art/portraits/*.png  # character portraits (source of truth, from the sprite sheets)
    art/*.ans            # pre-rendered truecolor portraits + BBS-style art (printed raw)
    art/*.txt            # hand-drawn ASCII art (colourised per host at runtime)
  bin/
    prompt-preview       # see every theme with live colour
    preview-html         # render themes + MOTDs to a browser gallery
    ansi2html.py         # ANSI→HTML (used by preview-html)
```

## Try before installing

```bash
bin/prompt-preview              # all themes in your terminal
bin/preview-html ~/preview.html # a browser gallery (themes + every MOTD)
bin/prompt-preview --motd bender
```

After installing, updates are just `git pull` in `~/.homelab-shell` (or
`./deploy-client.sh` again, which pulls for you) — edit here, commit, push,
pull everywhere, done.

> The main [homelab](https://github.com/bad1dea/homelab) repo's fleet servers
> get this same `shell/` directory via `scripts/deploy-shell.sh` /
> `sync-hosts.sh` — this repo is just the client-friendly extract, kept in
> sync by hand for now.

## In-shell control: `hl`

Once installed, manage everything live without re-sourcing:

| command           | what it does                                  |
|-------------------|-----------------------------------------------|
| `hl theme <name>` | switch prompt theme instantly (writes config) |
| `hl list`         | list available themes                         |
| `hl motd`         | reprint the full message-of-the-day           |
| `hl art`          | just the ANSI banner                          |
| `hl quote`        | a random in-character quote                    |
| `hl who`          | which character this host is                   |
| `hl reload`       | re-source after a `git pull`                    |

## The themes

- **simple** — one clean line: `⬡ user@host ~/dir (main*) $`
- **fancy** — two lines: host · git · exit-code · timing, then a `❯` that goes
  red on failure. The default.
- **modern** — Powerline segment bar. Needs a Powerline/Nerd font for the
  arrowheads; set `SEP=ascii` in the config to fall back to plain separators.
- **minimal** — almost nothing; only shows the host glyph when you're remote.
- **classic** — the nostalgic `[user@host dir]$`, lightly themed.
- **starship** — hands off to [starship](https://starship.rs) if installed
  (`install.sh --with-starship`). Config in `themes/starship.toml`.

## The MOTD

Printed on SSH login (`MOTD=auto`), or every login (`always`), or never (`off`).
Shows: character art, OS/kernel, uptime+load, memory, disk, ZeroTier IP, docker
container health, failed systemd units, logged-in users, **and whether the host
is behind the repo** (commits to pull) — plus a random in-character quote.

Art selection (`MOTD_ART` in config):
- `host` — the character portrait for this host (default)
- `shuffle` — a random piece every login
- `daily` — changes once per day, stable within the day
- `off` — no art

**Portraits (multi-variant, shuffles on join).** Each character has *several*
pose variants in `motd/art/portraits/<char>-NN.png` (cropped from the Futurama
sprite sheets + individual references). In `host` mode the MOTD picks a **random
variant of this host's character every login**; in `shuffle` mode, any character.
On hosts with **chafa** (`install.sh --with-fonts`) the PNG renders *live*
(terminal-adaptive); otherwise the pre-rendered `motd/art/<name>.ans` is used.

```bash
motd/render-portraits.sh                 # (re)render every PNG -> .ans
bin/portrait-review [out.html]           # browser gallery of all variants, labelled
motd/art/prune <name>...                 # delete bad variant(s) (PNG + .ans)
```

Curating is just deleting files — the shuffle globs whatever remains, no code
changes. Add a new variant by dropping a PNG in `portraits/` and re-rendering.

Drop your own art into `motd/art/`: `*.txt` is colourised to the host's colour,
`*.ans` is printed raw (use this for real CP437/ANSI BBS art). Generate figlet
banners with `motd/generate-art.sh --all` (after `install.sh --with-fonts`).

## Config file

`~/.config/homelab-shell.conf` (written by `install.sh`, edited live by `hl`):

```ini
THEME=fancy        # simple|fancy|modern|minimal|classic|starship
MOTD=auto          # auto (SSH only) | always | off
MOTD_ART=host      # host | shuffle | daily | off
SEP=pl             # pl | ascii  (modern theme separators)
```

Environment overrides win over the file: `HOMELAB_SHELL_THEME`,
`HOMELAB_SHELL_MOTD`, `HOMELAB_MOTD_ART`.

## Adding a host / character

Hosts named after a Futurama character are auto-recognised. To add one (or
re-skin an existing box), add a `case` arm in `lib/futurama.sh` (name, glyph,
256-colour, 16-colour fallback, quote tag), optionally drop `motd/art/<host>.txt`,
and add quotes tagged with that character to `motd/quotes.txt`. Unknown hosts get
a deterministic colour and a generic New-New-York persona — nothing breaks.

## Design notes

- **Zero hard dependencies.** Pure-bash themes; the MOTD degrades if docker/
  zerotier/systemd/figlet/lolcat are absent. 256-colour with a 16-colour fallback.
- **Safe in non-interactive shells.** `shell-common.sh` returns early for scp/
  git/cron so it can't break automation.
- **Idempotent everywhere.** `install.sh` manages a single marked block in
  `~/.bashrc`; re-running or `--uninstall` is clean.
- **One source of truth.** `lib/futurama.sh` defines every host's look; themes
  and the MOTD both read it, so a colour change lands in both at once.
