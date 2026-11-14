# fxclaude

Run separate Claude desktop windows for different accounts on macOS.

This package is adapted from [fxcodex](https://github.com/CaptureContext/fxcodex).
It keeps the same Swift package structure, dependency clients, workspace storage,
terminal prompts, and versioned JSON output.

## Requirements

- macOS 14 or later
- The Claude desktop app for `fxclaude open`
- The `claude` executable (Claude Code) in `PATH` for `fxclaude cli` and
  `fxclaude exec`
- Swift 6.3 or later only when building from source

## Installation

### Download a release

Download these files from the
[latest GitHub release](https://github.com/CaptureContext/fxclaude/releases/latest):

- `fxclaude-universal-apple-darwin`
- `fxclaude-universal-apple-darwin.sha256`

The universal executable runs natively on both Apple silicon and Intel Macs.
Smaller architecture-specific `aarch64` and `x86_64` artifacts are available
from the same release.

Verify and install the universal executable:

```sh
cd ~/Downloads
shasum -a 256 --check fxclaude-universal-apple-darwin.sha256
install -d "$HOME/.local/bin"
install -m 755 fxclaude-universal-apple-darwin "$HOME/.local/bin/fxclaude"
"$HOME/.local/bin/fxclaude" version
```

If `fxclaude` is not found, add this line to `~/.zshrc` and start a new shell:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Release executables are signed with a Developer ID Application certificate,
use the hardened runtime and a secure timestamp, and are notarized by Apple.
fxclaude has no self-updater yet; install a newer release the same way to
update.

### Build from source

Clone the repository with a Swift 6.3 toolchain available, then run:

```sh
make test
make install
```

`make install` builds a release executable and installs it to
`~/.local/bin/fxclaude`. Set `PREFIX` to choose a different installation
prefix. `make build`, `make release`, and `make universal` use the same build
workflow as fxcodex.

## Use different accounts

Your existing Claude profile is available as `primary`. Create another workspace
and sign in to the new Claude window with a different account:

```sh
fxclaude workspace create work --use --open
```

Both accounts can remain open. These commands open the requested workspace or
focus its existing instance:

```sh
fxclaude open primary
fxclaude open work
```

`fxclaude open` offers an interactive workspace picker. `fxclaude use work`
selects the default workspace without closing any running windows.

A workspace is an account profile, not a source-code directory. Names use
lowercase letters, numbers, and hyphens, and must start and end with a letter
or number.

| Task | Command |
| --- | --- |
| List workspaces | `fxclaude workspace list` |
| Create a workspace | `fxclaude workspace create <name>` |
| Open or focus a window | `fxclaude open [name]` |
| Deliver a link to one workspace | `fxclaude open-url <name> <url>` |
| Select the default workspace | `fxclaude use [name]` |
| Show running instances | `fxclaude status --all` |
| Show profile directories | `fxclaude workspace paths [name]` |
| Print a profile directory | `fxclaude workspace paths work --print user-data` |
| Run Claude Code in a workspace | `fxclaude cli [name] [-- args]` |
| Run `claude -p` in a workspace | `fxclaude exec [name] [-- args]` |
| Clear a managed profile | `fxclaude erase [name ...]` |
| Delete managed profiles | `fxclaude delete [name ...]` |

Erase and delete require confirmation. Close the affected Claude instances first.
The primary profile cannot be erased or deleted. `erase` retains the workspace
name and ID; the next launch starts with an empty profile.

## Deliver links to a workspace

A plain `open claude://…` reaches whichever Claude instance macOS picks. To hand
a link, such as a sign-in callback, to one workspace's Claude:

```sh
fxclaude open-url work 'claude://login/callback?code=…'
```

If that workspace's Claude is running, fxclaude sends the link to its process
only, as a `kAEGetURL` Apple Event addressed by process ID, the same event Launch
Services would send. If it is not running, that workspace's Claude launches with
its own profile and the link. The link never goes through Launch Services'
scheme routing.

The command accepts the schemes the installed Claude registers in its
`CFBundleURLTypes` (`claude` and `msauth.com.anthropic.claudefordesktop` today).
It exits non-zero with a one-line message on stderr when the workspace doesn't
exist, Claude doesn't handle the link, or delivery fails. `--json` returns the
workspace, process ID and `delivery` (`apple-event` or `launch`).

The first link sent to a running instance can trigger macOS's Automation prompt
("… wants to control Claude") for the app that runs fxclaude, such as Terminal
or Arx. If it was declined, allow it in System Settings > Privacy & Security >
Automation.

In Arx, Air Traffic Control can run a script for `claude://` links, chosen per
profile, with the link as `$1`:

```sh
fxclaude open-url work "$1"
```

## How isolation works

fxclaude uses the installed `Claude.app`, identified by
`com.anthropic.claudefordesktop`. Each managed instance starts through macOS
Launch Services with `createsNewApplicationInstance` enabled and its own
`CLAUDE_USER_DATA_DIR` and `--user-data-dir` path. Claude's bootstrap directs
profile data and logs to that directory. The instance also gets its own
`CLAUDE_CONFIG_DIR`; see [Claude Code per workspace](#claude-code-per-workspace). fxclaude records the process ID,
launch date, and bundle location to find the correct window later.

The environment override was verified in the installed Claude 4.29.0 app.
It is an internal desktop-app behavior, so future Claude releases may change it.
Sign in separately in each managed window. fxclaude does not copy credentials
from the primary profile.

Managed data lives in:

```text
~/Library/Application Support/fxclaude/
├── configuration.json
├── runtime.json
├── storage.lock
└── workspaces/
    └── <workspace-id>/
        ├── workspace.json
        ├── claude-config/
        └── user-data/
```

`primary` uses `~/Library/Application Support/Claude` and `~/.claude`, or the
locations specified by `CLAUDE_USER_DATA_DIR` and `CLAUDE_CONFIG_DIR`. `FXCLAUDE_HOME` overrides fxclaude's support directory
for isolated testing or a separate installation. Profile directories contain
private account data; keep them out of source control.

## Claude Code per workspace

Each managed workspace also has its own Claude Code config directory,
`claude-config/`, used in the same way fxcodex uses `CODEX_HOME`:

- `fxclaude open` launches the desktop app with `CLAUDE_CONFIG_DIR` set to it,
  so the Code tab stops sharing `~/.claude` (settings, history, memory,
  projects, plugins, `.claude.json`) with other workspaces.
- `fxclaude cli` runs `claude` from `PATH` with the same `CLAUDE_CONFIG_DIR`, and
  `fxclaude exec` runs `claude -p`. The app's Code tab and the terminal share
  one config directory per workspace.

```sh
fxclaude cli work
fxclaude cli work -- --resume
fxclaude exec work -- --output-format json "Summarize the open PRs"
fxclaude workspace paths work --print claude-config
```

Without a name, both commands use the current workspace. Arguments after the
workspace name go to Claude Code; put `--` first when the first argument could
be read as a workspace name, as in `fxclaude exec -- "fix the tests"`.
`fxclaude cli --help` shows fxclaude's help; `fxclaude cli -- --help` shows
Claude Code's. Neither command supports `--json`, and fxclaude's own `--json`
is not read after `cli` or `exec`.

`primary` sets nothing. It keeps `~/.claude`, or a `CLAUDE_CONFIG_DIR` that is
already in the environment. Workspaces created before this directory existed get
an empty `claude-config/` the next time fxclaude runs. The storage schema stays
at 2.0, so older fxclaude versions still read it. `erase` clears `claude-config/`
along with `user-data/`.

### What the desktop app does with `CLAUDE_CONFIG_DIR`

Checked in Claude 5.11492.0 with bundled Claude Code 2.1.321, by reading the
app's `app.asar` and the Claude Code binary. It was not checked by launching a
signed-in managed instance. Like `CLAUDE_USER_DATA_DIR`, this is internal app
behavior that a later release may change.

- **The Code tab inherits it.** The app builds each Code session's environment
  from a copy of its own (`{...process.env}`), then adds its own variables, and
  none of them is `CLAUDE_CONFIG_DIR`. The app also reads the variable from your
  login shell, but only when its launch environment lacks it, so the launch
  value wins. A `CLAUDE_CONFIG_DIR` set in the app's Settings overrides both;
  those settings live in the workspace's own `user-data/`.
- **The Code tab's login comes from the app account, not from the config
  directory.** The app passes its signed-in account to Claude Code as
  `CLAUDE_CODE_OAUTH_TOKEN`, with account, organization and email variables.
  It also refreshes the token for the session. Claude Code prefers that token
  over its stored login. Signing in to a managed Claude window is enough for its
  Code tab.
- **The terminal needs its own login.** `fxclaude cli` has no app token.
  Claude Code keeps its login in a Keychain item named after the config
  directory: `Claude Code-credentials` for `~/.claude`, and
  `Claude Code-credentials-<first 8 hex of sha256(path)>` for any other
  `CLAUDE_CONFIG_DIR`. Run `/login` once in `fxclaude cli <name>` for each
  workspace. Use the same account as that workspace's Claude window: when the
  app's token is rejected, the Code tab can fall back to the token in this
  Keychain item.

## Automation and Raycast integration

The CLI retains stable workspace IDs and the fxcodex JSON envelope:

```sh
fxclaude --json status --all
fxclaude workspace list --json
fxclaude open --workspace-id <uuid> --json
fxclaude open-url work 'claude://…' --json
FXCLAUDE_JSON=1 fxclaude workspace paths work
```

Responses include `api_version`, `ok`, and either `data` or `error`. Use
`--no-json` to override the environment. For scripted deletion, supply workspace
names and `--yes` explicitly.

The companion fxclaude Raycast extension uses this API for workspace management,
custom icons, status, and diagnostics. Its icon metadata is stored through:

```sh
fxclaude integrations attributes get raycast --path workspaces --json
fxclaude integrations attributes set raycast '{"type":"raycast","value":"folder-16"}' --path 'workspaces.[key: <uuid>].icon' --json
```

The extension includes its own CLI copy and can also use an external fxclaude
0.1.0 or later. Workspace and application renaming are omitted.

### Install Raycast and the extension

Run either command without a trailing action to choose interactively:

```sh
fxclaude integrations
fxclaude integrations raycast
```

`status` reports whether Raycast and Raycast Beta are installed. `install`
offers Raycast, Raycast Beta, and the fxclaude extension:

```sh
fxclaude integrations raycast status
fxclaude integrations raycast install app
fxclaude integrations raycast install app --beta
fxclaude integrations raycast install extension
```

`install app` uses `brew install --cask raycast`. Raycast Beta has no Homebrew
cask and requires Apple silicon and macOS 26 or later, so `install app --beta`
opens its official download page instead.

`install extension` opens the extension's Raycast deep link
(`raycast://extensions/maximkrouk/fxclaude`). When both Raycast and Raycast Beta
are installed, fxclaude asks which one to use. When neither is installed, it
recommends installing Raycast first and offers the Raycast Store page as a
fallback. `--yes` installs Raycast without asking, and `--open-in-browser` opens
the [Store page](https://www.raycast.com/maximkrouk/fxclaude) directly. Both
`status` and `install` accept `--json`; `install` then needs an explicit
component and never prompts.

Unlike fxcodex, fxclaude does not generate Raycast Script Commands.

## Publishing a release

Release versions use plain semantic versions such as `0.1.0` (without a `v`
prefix). Update the embedded version in
`Sources/fxclaude-cli/AppCommand.swift`, run `make test`, and push the
release-ready commit to `main`. Then run the `Release` workflow from GitHub
Actions and enter that version.

The workflow pins the release to the selected `main` commit, verifies that the
version matches the executable, resolves one dependency graph for both
architectures, builds and tests on Apple silicon and Intel runners, and signs
and notarizes all final executables. After every check succeeds, it creates the
tag and publishes the release with post-signing SHA-256 checksum files:

- `fxclaude-aarch64-apple-darwin`
- `fxclaude-x86_64-apple-darwin`
- `fxclaude-universal-apple-darwin`

The release also includes the exact `Package.resolved` used by both builds.
See [Documentation/Releases.md](Documentation/Releases.md) for the required
organization secrets, variables, and environment.

## License

fxclaude is not affiliated with Anthropic. The inherited code is MIT licensed;
see [LICENSE](LICENSE).
