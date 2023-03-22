# Anti-SteamID-Changer
Identifies players with SteamID substitution

A plugin for servers that does not allow clients to change their SteamID. It works by checking if the player's IP address and SteamID match, and if they do not, it executes a punishment command, which can be defined in the plugin configuration file.

Overall, this plugin provides a basic but effective way of preventing players from changing their SteamID during gameplay on a gaming server. However, it is not foolproof and can be bypassed

## Usage

1. Put the contents of the scripting folder in the directory of your server (your_server_folder/cstrike/addons/amxmodx/scripting)
2. Compile `anti_steamidchanger.sma` [how to compile?](https://dev-cs.ru/threads/246/)
3. Add `anti_steamidchanger.amxx` into your `plugins.ini` file
4. Restart server or change map
5. After restarting the server or changing the map, a config will be created in the folder `/cstrike/addons/amxmodx/configs/plugins` with the name `anti_steamid_change.cfg`.

## Cvars
`asc_flags` - Flag for access to the asc_add_white and asc_clear_cache commands

`asc_reason` - The reason for the punishment

`asc_command` - The command to execute the punishment

## Commands


`asc_clear_cache` - Console command to clear the cache collected on the current map. The cache is needed to avoid duplicate bans

`asc_add_white` - Console command to add IP player present on the server in the white list.

## White list

File - `settings_asc_whitelist` in `addons/amxmodx/configs/settings` folder.

Useful for players who play in computer clubs, and similar, who comes from multiple devices with one network (family etc.)

Note: Players in the white list plugin does not check for ban bypass.

File format is:
```
; Formatting file is: <ip> ; comment
127.0.0.1 ; This is a comment
0.0.0.0 ; It's my friend Liciy, he plays on server with step sister in one time
```