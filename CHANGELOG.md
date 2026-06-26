# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-27

### Added
- UE4SS Lua mod with command registry and in-game console commands (`wrc <command>`).
- Built-in commands: `help`, `players`, `kick`, `ban`, `tp`, `getpos`, `broadcast`, `say`, `dchat`, `give`, `settime`, `spawn`, `kill`, `heal`, `version`, `login`, `logout`.
- Admin password system required for all admin commands across console, file bridge, RCON, and REST API.
- Source RCON-compatible TCP server running inside the game process via `windrose_rcon.dll`.
- C++ networking DLL (`windrose_rcon.dll`) with TCP socket API and HTTPS POST (WinHTTP) for Lua.
- JSON REST API with token authentication on port `8780`.
- Built-in web admin dashboard served at `/` with status, console, config editor, whitelist, and banlist.
- Config/whitelist/banlist management endpoints and runtime config storage.
- Discord webhook integration (`dchat`, `broadcast`, `say`, and optional in-game chat hook).
- Windrose-safe `UE4SS-settings.ini` that avoids common crash hooks.
- PowerShell install script (`install.ps1`) and single complete release zip (`WindroseRCON-Complete-v1.0.0.zip`).
- Standalone Lua tests: `test_mod.lua`, `test_rcon.lua`, `test_rest_api.lua`, `test_json.lua`, and `test_dashboard.lua`.
- English documentation: `README.md`, `docs/commands.md`, `CHANGELOG.md`, and `LICENSE`.

### Notes
- Game class names (`R5Character`, `R5PlayerState`, `R5GameState`, `R5GameMode`, `R5PlayerController`) are based on community findings and may need updates after game patches.
- Some commands rely on guessed Unreal Engine method names and may need adjustment in `game_api.lua`.
