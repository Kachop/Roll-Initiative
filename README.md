# Roll-Initiative
A gui desktop app for managing combats and encounters in D&amp;D. Has a web based player view to display the important information to the players.

This program is designed to be an all in 1 combat manager. To help the DM and players keep track of health, temp HP and conditions during combat. Designed to improve the D&amp;D combat experience.

## Features

Most of the core features for running combat are implemented but more features are planned.

Current features:
- Save and load pre-planned combats
- Add, edit and save PC's and NPC's
- Custom icons and borders for your combatants
- Apply conditions during combat
- Damage vulnerabilities, resistances and immunities accounted for in damage calculations
- Temporary vulnerabilities, resistances and immunities can be added during combat
- Temporary HP system
- Combat and turn timer
- Web based player view which can be cast from the browser or displayed on any device connected to the same WiFi
- Combat log generation. A human readable file which tracks turn by turn actions in each combat.

Planned features:
- Full stats logging per combat
- Music controls and playlists linked to saved combats
- Player view animations for a more immersive experience
- Random combat generator

The program is still under development so there are some bugs to iron out.

## How to use
No install required. Just clone the repository and run the executable (available for Windows and Linux).

> [!IMPORTANT]
> A knowns issues is that the browser will not automatically open on Windows systems. So you will have to open the browser yourself and go to the address shown on the combat screen.

## Build from source
To build from source simply clone the repository, navigate to it and use one of the following commands.
On Linux:
> `odin build src/ -out:Roll-Initiative`
On Windows:
>`odin build src/ -out:Roll-Initiative.exe -define:RAYLIB_SHARED=true`

## Screenshots
![Example of the icons customising tool.](/Screenshots/working_borders.png)

</br>

![Example of the player view listing some PC's with their icons.](/Screenshots/Web_view.png)
