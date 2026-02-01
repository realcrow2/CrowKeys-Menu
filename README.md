# CrowKeys - Vehicle Keys System

Created by **Crow**

A FiveM resource that provides Discord ID-based vehicle ownership and locking with an advanced trust system. Features a beautiful HTML/NUI menu interface for managing vehicles and permissions.

## Features

- **Discord ID Based Vehicle Ownership**: Vehicles are locked to Discord IDs specified in `config.json`
- **Advanced Trust System**: Vehicle owners can trust their vehicles to other players with persistent storage
- **HTML/NUI Menu Interface**: Beautiful, responsive menu for viewing, spawning, and managing vehicles
- **Access Control**: Automatic real-time checking of vehicle access - unauthorized vehicles are deleted when driven by unauthorized players
- **Trust Management**: View who has access to your vehicles and manage permissions through an intuitive interface
- **Webhook Integration**: Optional Discord webhook support for logging trust/untrust actions
- **Easy Configuration**: Simple JSON configuration file
- **Persistent Trust Storage**: Trust relationships are saved to `trusted.json` and persist across server restarts

## Requirements

- FiveM Server
- [ox_lib](https://github.com/overextended/ox_lib) - Required for notifications and shared scripts

## Installation

1. Download this script and place it in your `resources` folder
2. Ensure `ox_lib` is installed and started before this resource
3. Add to your `server.cfg`:
   ```
   ensure ox_lib
   ensure CrowKeys
   ```
4. Configure `config.json` with Discord IDs and vehicle spawn codes
5. (Optional) Configure Discord webhook URL in `config.json` for trust action logging

## Configuration

Edit `config.json` to add Discord IDs and their vehicles:

```json
{
    "vehicles": {
        "DISCORD_ID_1": [
            "adder",
            "zentorno",
            "t20"
        ],
        "DISCORD_ID_2": [
            "zentorno",
            "turismor"
        ]
    },
    "settings": {
        "checkDiscordOnJoin": true,
        "enableSpawnProtection": true,
        "webhookUrl": "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
    }
}
```

**Configuration Options:**
- `vehicles`: Object mapping Discord IDs to arrays of vehicle spawn codes
- `checkDiscordOnJoin`: If `true`, players without Discord IDs will be kicked on join
- `enableSpawnProtection`: If `true`, spawn protection is enabled (prevents spawning in blocked areas)
- `webhookUrl`: (Optional) Discord webhook URL for logging trust/untrust actions. Set to `"ChangeME"` or empty string to disable

**Important Notes:**
- Use actual Discord IDs (numbers, not usernames)
- Vehicle spawn codes must match GTA V vehicle names (case-insensitive)
- To find a player's Discord ID, check your server console when they join or use a Discord ID lookup tool
- Trust relationships are automatically saved to `trusted.json` and persist across restarts

## Commands

### `/keys`
Opens a beautiful HTML menu showing all vehicles you own or have been trusted with. Navigate with arrow keys, select with Enter, and close with ESC. Click on a vehicle to spawn it.

**Usage:** `/keys`

### `/trust`
Opens a trust menu where you can select vehicles and enter a player ID to grant access. You can select multiple vehicles or use the "Select All" option to trust all your vehicles at once.

**Usage:** `/trust`
- Enter the target player's server ID in the input field
- Select one or more vehicles from the list (or select all)
- Click "Trust Player" to grant access

### `/trusted`
Opens a menu showing all players who have been trusted with your vehicles. Includes a search function to filter by vehicle name or player name/Discord ID. You can remove trust directly from this menu.

**Usage:** `/trusted`
- View all vehicles and their trusted players
- Use the search bar to filter results
- Click the remove button next to a player to revoke their access

## How It Works

1. **On Join**: When a player joins, their Discord ID is checked against the configuration
2. **Vehicle Spawning**: Use `/keys` to open the menu and spawn your vehicles. Vehicles spawn in front of you and you'll automatically be warped into the driver's seat
3. **Access Control**: The script continuously monitors vehicle access:
   - When a player enters or drives a vehicle, the system checks if they have permission
   - If a player without access enters a restricted vehicle, they receive a notification and the vehicle is deleted
   - Access is checked in real-time, so if trust is removed while a player is driving, the vehicle will be deleted
4. **Trust System**: 
   - Vehicle owners can trust their vehicles to other players using `/trust`
   - Trust relationships are saved to `trusted.json` and persist across server restarts
   - Trusted players can drive vehicles but cannot spawn them or grant access to others
   - Owners can view and manage trusted players using `/trusted`
5. **Vehicle Protection**: 
   - Only vehicles listed in `config.json` are protected
   - Vehicles not in the config are not locked and anyone can drive them
   - Spawned vehicles are automatically registered and protected

## File Structure

- `config.json` - Vehicle ownership configuration and settings
- `trusted.json` - Persistent storage for trust relationships (auto-generated)
- `client/main.lua` - Client-side vehicle spawning, access checking, and menu handling
- `server/main.lua` - Server-side permission management, trust system, and Discord ID handling
- `html/` - HTML/NUI menu interface files

## Notes

- Vehicle spawn codes must be exact GTA V vehicle model names (case-insensitive)
- Only the vehicle owner can use `/trust` and `/trusted` commands
- Trusted players can drive vehicles but cannot spawn them or trust vehicles to others
- Vehicles not in `config.json` are not locked and anyone can drive them
- Trust relationships persist across server restarts via `trusted.json`
- If a vehicle is removed from a player's config, all trust relationships for that vehicle are automatically cleaned up
- Webhook notifications include owner, target player, and vehicle information with Discord mentions

## Troubleshooting

**Discord ID not found:**
- Make sure players are logged into Discord
- Check that Discord integration is enabled on your server
- Verify the player has Discord linked to their FiveM account

**Vehicle not spawning:**
- Verify the spawn code in `config.json` matches the exact GTA V vehicle name
- Check server console for errors
- Ensure the spawn location is clear (not blocked by other vehicles or objects)

**Menu not opening:**
- Ensure `ox_lib` is installed and started
- Check that you have vehicles in your `config.json`
- Verify your Discord ID is correctly configured
- Check browser console (F8 in-game) for JavaScript errors

**Trust not working:**
- Verify both players have valid Discord IDs
- Check that the vehicle exists in the owner's config
- Ensure `trusted.json` has proper write permissions
- Check server console for errors

**Webhook not sending:**
- Verify the webhook URL is correct and active
- Check that the URL is properly formatted in `config.json`
- Ensure the webhook has proper permissions in your Discord server

## Support

For issues or questions, check your server console for error messages. Make sure all dependencies are properly installed and configured. The script uses Lua 5.4 and requires FiveM server build 2372 or higher.

<img width="338" height="487" alt="image" src="https://github.com/user-attachments/assets/4baeb2fe-44f4-4a92-8559-230d017275d6" /> <img width="374" height="417" alt="image" src="https://github.com/user-attachments/assets/8754253b-cd3d-4c89-95ac-f9d0a9d97a0f" />

