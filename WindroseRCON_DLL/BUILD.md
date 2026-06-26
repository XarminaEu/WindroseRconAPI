# Building windrose_rcon.dll

This DLL is a Lua C extension that gives the WindroseRCON Lua mod access to TCP sockets. It is loaded by `require("windrose_rcon")` in `rcon_server.lua`. Lua 5.4.7 is built statically into the DLL so no extra `lua54.dll` is required at runtime.

## Prerequisites

- Windows 10/11
- Visual Studio 2022 or Build Tools with the **Desktop development with C++** workload
- CMake 3.20+ (optional if you use the Visual Studio project directly)

## Build with CMake (recommended)

Open a **x64 Native Tools Command Prompt for VS 2022** and run:

```cmd
cd WindroseRCON_DLL
cmake -S . -B build -A x64
cmake --build build --config Release
```

The output is placed at `WindroseRCON/Scripts/windrose_rcon.dll` by the CMake target properties.

## Build with the batch file

Double-click or run `build.bat` inside a Visual Studio Developer Command Prompt:

```cmd
cd WindroseRCON_DLL
build.bat
```

## Build with MinGW-w64

If you use MinGW instead of Visual Studio:

```cmd
cd WindroseRCON_DLL
cmake -S . -B build -G "MinGW Makefiles"
cmake --build build
```

## Troubleshooting

- **Cannot find lua.h**: Lua 5.4.7 source is included in `deps/lua-5.4.7/`. Update `LUA_ROOT` in `CMakeLists.txt` if you want a different version.
- **Unresolved lua symbols**: Lua is built statically into the DLL. Make sure the Lua version matches the one used by UE4SS (5.4.x). If you change `LUA_ROOT`, ensure the new source is compatible.
- **DLL does not load**: Ensure `windrose_rcon.dll` is placed in `WindroseRCON/Scripts/` next to the Lua files. Check the UE4SS console for the exact load error. If UE4SS uses a different Lua ABI, the DLL may need to be rebuilt against that version.

## Testing

After building, the CMake project also produces a minimal `lua_test.exe` in `build/Release/`. You can use it to verify the DLL loads:

```cmd
cd WindroseRCON
copy ..\WindroseRCON_DLL\build\Release\lua_test.exe .
..\WindroseRCON_DLL\build\Release\lua_test.exe test_mod.lua
..\WindroseRCON_DLL\build\Release\lua_test.exe test_rcon.lua
```

The repository includes:
- `test_mod.lua` — tests the command registry, auth, login/logout logic.
- `test_rcon.lua` — tests the full Source RCON protocol: auth, command, response.

## What the DLL exports

- `windrose_rcon.init()` — Initialize Winsock.
- `windrose_rcon.connect(host, port, timeout_ms)` — Connect to a TCP server.
- `windrose_rcon.bind(host, port)` — Create a listening TCP socket (non-blocking).
- `windrose_rcon.accept(server, timeout_ms)` — Accept a new connection.
- `windrose_rcon.receive(socket, max_len)` — Receive data.
- `windrose_rcon.send(socket, data)` — Send data.
- `windrose_rcon.close(socket)` — Close a socket.
- `windrose_rcon.select({sockets}, timeout_ms)` — Check which sockets are readable.
- `windrose_rcon.getsockname(socket)` — Get bound IP and port.

All socket handles are returned as Lua integers (Windows `SOCKET` descriptor values).
