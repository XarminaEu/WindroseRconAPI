# WindroseRCON

A server-side admin/RCON framework for Windrose powered by [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS). It runs a Source RCON-compatible TCP server **inside the game process** via a small C++ DLL, so you can manage your dedicated server remotely without any external process.

> **Note:** This is a starter framework. Windrose game classes and function names may change with patches. The included commands are designed to be extended, not a drop-in replacement for a fully finished admin tool like PalDefender.

## Features

- UE4SS Lua mod that registers in-game console commands (`wrc <command>`)
- Command registry that is easy to extend with new commands
- Source RCON-compatible TCP server running **inside the game process** (no external server needed)
- Small C++ networking DLL (`windrose_rcon.dll`) loaded by the Lua mod
- Windrose-safe UE4SS settings that avoid common crash hooks
- Admin password system required for all admin commands (console, file bridge, and RCON)
- Admin whitelist, RCON password, and logging configuration

## Project Layout

```
WindroseRCON/
├── WindroseRCON/               # UE4SS mod folder (extract to R5/Binaries/Win64/ue4ss/Mods/)
│   ├── enabled.txt
│   ├── Data/                   # Runtime config / logs
│   └── Scripts/
│       ├── main.lua            # Entry point
│       ├── config.lua          # Config loader
│       ├── config_user.lua     # User-editable config
│       ├── auth.lua            # Admin password / session auth
│       ├── command_registry.lua
│       ├── commands.lua        # Built-in commands
│       ├── rcon_server.lua     # In-process RCON server
│       ├── game_api.lua        # Windrose game wrappers
│       ├── utils.lua           # Helpers
│       └── windrose_rcon.dll   # Pre-built C++ networking DLL
├── WindroseRCON_DLL/           # C++ networking DLL source
│   ├── CMakeLists.txt
│   ├── deps/lua-5.4.7/         # Lua 5.4 source (built into the DLL)
│   ├── src/windrose_rcon.cpp
│   ├── build.bat
│   └── BUILD.md
├── BuildZips/                  # Pre-packaged release zips
├── UE4SS-settings.ini          # Windrose-safe UE4SS settings
├── install.ps1                 # PowerShell install script
├── test_mod.lua                # Lua logic test
├── test_rcon.lua               # RCON protocol test
├── docs/
│   └── commands.md             # Command reference
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Requirements

- Windrose Dedicated Server on Windows
- UE4SS experimental build for UE 5.6
- Visual Studio 2022 (or Build Tools) with C++ workload, or MinGW-w64, to compile the DLL

## Build the DLL

1. Open a Visual Studio Developer Command Prompt.
2. Navigate to `WindroseRCON_DLL/`.
3. Run:
   ```powershell
   cmake -S . -B build -A x64
   cmake --build build --config Release
   ```
4. This produces `WindroseRCON/Scripts/windrose_rcon.dll`.

For MinGW:
```powershell
cmake -S . -B build -G "MinGW Makefiles"
cmake --build build
```

### Test

After building, run the standalone tests with the included `lua_test.exe`:

```powershell
cd WindroseRCON
..\WindroseRCON_DLL\build\Release\lua_test.exe test_mod.lua
..\WindroseRCON_DLL\build\Release\lua_test.exe test_rcon.lua
```

- `test_mod.lua` tests the command registry, login/logout, and admin password enforcement.
- `test_rcon.lua` tests the full Source RCON protocol (auth, command, response).

## Installation

1. Install UE4SS into your Windrose server:
   - Extract `dwmapi.dll` and the `ue4ss` folder to `R5\Binaries\Win64\`.
2. Build the `windrose_rcon.dll` (see above).
3. Run the install script from your Windrose server root (the folder that contains `R5\Binaries\Win64\ue4ss`):
   ```powershell
   .\path\to\WindroseRCON\install.ps1
   ```
4. Verify that `windrose_rcon.dll` is present in:
   ```
   R5\Binaries\Win64\ue4ss\Mods\WindroseRCON\Scripts\
   ```
5. Edit the mod config:
   - Open `R5\Binaries\Win64\ue4ss\Mods\WindroseRCON\Scripts\config_user.lua`.
   - Set a strong `admin.password`. This is required for all admin commands.
   - If `rcon.password` is left empty, RCON will use the admin password.
   - Add admin Steam IDs if desired.
6. Start the Windrose server. The mod writes a log line when it loads and the RCON server is listening.

## Usage

### In-game Console

Open the UE console and type:

```
wrc login your-admin-password
wrc players
wrc broadcast Hello everyone!
wrc kick PlayerName "Spamming chat"
```

Admin commands require `login` first. The session stays authenticated until `logout` or the server restarts.

### RCON Client

Connect with any Source RCON client (e.g., mcrcon, RustAdmin, or a custom script):

```bash
mcrcon -H 127.0.0.1 -P 25575 -p your-password "players"
```

The server runs inside the game process on port `25575` by default.

### Direct Command File (No DLL / Fallback)

If the DLL is missing or RCON fails, the mod can also poll a plain text command file:

```text
WindroseRCON/Data/rcon_commands.txt
```

Format: `request_id|command|arg1|arg2|...`

Responses are written to:

```text
WindroseRCON/Data/rcon_responses.txt
```

Enable/disable this in `config_user.lua` with `rcon.fallback_file_bridge`.

## Adding Custom Commands

1. Open `WindroseRCON/Scripts/commands.lua`.
2. Add a new `CommandRegistry.Register(...)` call before the function ends.
3. Return a table: `{ success = true/false, message = "response text" }`.

Example:

```lua
CommandRegistry.Register("hello", function(args, ctx)
    return { success = true, message = "Hello from WindroseRCON!" }
end, "Says hello", {}, "any")
```

## Important Notes

- **WindrosePlus already exists.** If you want a full-featured solution with live map, web dashboard, and 30+ commands, check [WindrosePlus](https://github.com/HumanGenome/WindrosePlus). This project is intended as a lightweight, self-built alternative.
- The game class names (`R5Character`, `R5PlayerState`, etc.) are based on community findings. They may need updating after a game patch.
- Commands that modify the game world run through `ExecuteInGameThread` to avoid threading issues.
- Some commands (kick, ban, heal, kill) rely on guessed function names. If a command fails, inspect the UE4SS log and update `game_api.lua` with the correct method names.

## License

MIT
