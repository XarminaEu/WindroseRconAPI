# WindroseRCON Command Reference

Commands can be run from the in-game console as `wrc <command> [args]` or via RCON.

## General

- `help` - Lists all registered commands.
- `version` - Shows the WindroseRCON version.
- `login <password>` - Authenticates the current session with the admin password.
- `logout` - Clears the current session's admin authentication.

## Admin Password

All commands except `help`, `version`, `login`, and `logout` are considered admin commands and require authentication:

- **RCON clients** are authenticated by the Source RCON password (defaults to `admin.password` if `rcon.password` is empty).
- **In-game console** users must run `login <password>` first.
- **File bridge** clients must send `login|<password>` before admin commands, or set `admin.password` separately.

Set `admin.password` in `config_user.lua`. If it is empty, admin commands will be rejected.

## Player Management

- `players` - Lists all online players with name, player ID, ping, and position.
- `kick <UserId> [Reason]` - Kicks a player from the server.
- `ban <UserId> [Reason]` - Kicks a player and appends a ban entry to the log file.
- `say <UserId> <Message>` - Sends a private message to a player.
- `getpos <UserId>` - Shows the player's current world position.

## Teleport & Movement

- `tp <UserId> <X> <Y> [Z]` - Teleports a player to coordinates. `Z` defaults to `0` if omitted.

## World

- `broadcast <Message>` - Sends a message to all players.
- `settime <hour>` - Sets the server time hour (0-23).
- `spawn <CreatureId> <X> <Y> <Z> [Level]` - Spawns a creature at coordinates.

## Items & Health

- `give <UserId> <ItemId> [Amount]` - Gives an item to a player.
- `heal <UserId>` - Heals a player.
- `kill <UserId>` - Kills a player.

## Argument Notes

- `<UserId>` can match player name, `PlayerId`, or the Steam ID if exposed by the game.
- Arguments with spaces should be wrapped in quotes when sent via RCON.
- Coordinates are float values in the game world space.

## RCON Examples

```bash
mcrcon -H 127.0.0.1 -P 25575 -p your-password players
mcrcon -H 127.0.0.1 -P 25575 -p your-password "broadcast Server restart in 5 minutes"
mcrcon -H 127.0.0.1 -P 25575 -p your-password "give PlayerName Wood 100"
```

## Console Examples

```
wrc login your-password
wrc players
wrc kick SomePlayer "Rule violation"
wrc tp SomePlayer 14520 -8340 500
```

## File Bridge Example

```
1|login|your-password
2|players
3|broadcast Server restart in 5 minutes
```

## Extending Commands

Open `WindroseRCON/Scripts/commands.lua` and add a new `CommandRegistry.Register` entry. Each handler receives `(args, ctx)` where `args` is a table of string arguments and `ctx` contains `config` and `source`. Return `{ success = true/false, message = "response" }`.
