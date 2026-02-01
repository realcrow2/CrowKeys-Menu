# Vehicle Keys System

Created by **Crow**

A FiveM script for vMenu standalone servers that provides Discord ID-based vehicle locking with a trust system.

## Features

- **Discord ID Based Vehicle Ownership**: Vehicles are locked to Discord IDs specified in `config.json`
- **Trust System**: Vehicle owners can trust their vehicles to other players
- **ox_lib Menu**: Beautiful menu interface for viewing and spawning vehicles
- **Access Control**: Automatic checking of vehicle access - unauthorized vehicles are deleted when driven by unauthorized players
- **Easy Configuration**: Simple JSON configuration file

## Requirements

- FiveM Server
- [ox_lib](https://github.com/overextended/ox_lib) - Required for menu functionality

## Installation

1. Download this script and place it in your `resources` folder
2. Ensure `ox_lib` is installed and started before this resource
3. Add to your `server.cfg`:
   ```
   ensure ox_lib
   ensure vehicle-keys
   ```
4. Configure `config.json` with Discord IDs and vehicle spawn codes

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
        "enableSpawnProtection": true
    }
}
```

**Important Notes:**
- Use actual Discord IDs (numbers, not usernames)
- Vehicle spawn codes must match GTA V vehicle names (lowercase)
- To find a player's Discord ID, check your server console when they join

## Commands

### `/keys`
Opens an ox_lib menu showing all vehicles you own or have been trusted with. You can scroll through the list and click on a vehicle to spawn it.

**Usage:** `/keys`

### `/trust [player_id] [spawncode or all]`
Gives another player access to drive one or all of your vehicles. Trusted players cannot give the vehicle to others.

**Usage Examples:**
- `/trust 1 adder` - Trusts player with ID 1 to drive your adder
- `/trust 1 all` - Trusts player with ID 1 to drive all your vehicles

### `/untrust [player_id] [spawncode or all]`
Removes access from a player for one or all vehicles.

**Usage Examples:**
- `/untrust 1 adder` - Removes player ID 1's access to your adder
- `/untrust 1 all` - Removes player ID 1's access to all your vehicles

## How It Works

1. **On Join**: When a player joins, their Discord ID is checked
2. **Vehicle Spawning**: Use `/keys` to open the menu and spawn your vehicles
3. **Access Control**: The script automatically checks if a player has access when they:
   - Are driving a vehicle
   - If a player without access enters a vehicle, the vehicle will be deleted after a brief notification
4. **Trust System**: Vehicle owners can trust their vehicles to other players. Trusted players can drive but cannot give access to others.

## Notes

- Vehicle spawn codes must be exact GTA V vehicle model names (case-insensitive)
- Only the vehicle owner can use `/trust` and `/untrust` commands
- Trusted players can drive but cannot spawn or trust vehicles to others
- Vehicles not in the config.json are not locked and anyone can drive them

## Troubleshooting

**Discord ID not found:**
- Make sure players are logged into Discord
- Check that Discord integration is enabled on your server

**Vehicle not spawning:**
- Verify the spawn code in config.json matches the exact GTA V vehicle name
- Check server console for errors

**Menu not opening:**
- Ensure `ox_lib` is installed and started
- Check that you have vehicles in your config.json

## Support

For issues or questions, check your server console for error messages. Make sure all dependencies are properly installed.

