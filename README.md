# Duo Quest

A cooperative idle RPG for Roblox built around persistent two-player parties,
automated combat, seasonal resets and capped permanent account progression.

Built with Luau and synced into Roblox Studio using Rojo.

## Layout

```
default.project.json         Rojo project file
src/
  shared/                    -> ReplicatedStorage.Shared
    Config/                  data-only modules (Classes, Seasons, ...)
    Util/                    helpers (TableUtil)
    ProfileTemplate.luau     shape of a player profile
  server/                    -> ServerScriptService.Server
    Main.server.luau         starts services, connects players
    Services/DataService     session-locked loading and saving
    Tests/ProfileTests       run from the Studio command bar
```

## Working on it

1. Install Rojo (VS Code extension + Studio plugin).
2. Open this folder in VS Code, run **Rojo: Open Menu > Start server**.
3. In Studio, open a Baseplate, click **Connect** in the Rojo plugin.
4. After pulling new changes, the sync updates Studio automatically.

File naming: `Name.luau` = ModuleScript, `Name.server.luau` = Script,
`Name.client.luau` = LocalScript.
