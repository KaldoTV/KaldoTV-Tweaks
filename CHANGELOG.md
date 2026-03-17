## v0.3.6
### Fixes
- Buff checks : Now check if any valid target is on range

## V0.3.5
### Fixes
- Shaman : Flametongue enchantment is now searched in both main hand (Elemental) and off hand (Enhancement)
- Shaman : Tidecaller's guaard is no longer indicated as missing on Enhancement spec, as it's a passive spell

## v0.3.4
### Fixes
- Disable most of the buff check during Battleground because of secret values in auras

## v0.3.3
### Fixes
- Added a security to prevent MM+ module to read chat during encounters
  (MM+, combat mode, BG)
- Enhance buff detection

## v0.3.2
### Fixes
- Earth shield (non personal version) is now searched on anyone in the group but the shaman instead of the tank only
- Fix a filter issue when "only my buff" is unticked
- Add a new fallback when in combat/MM+ : when raid buff are glowing, they are displayed as missing
- Added new way of highlight my own buffs
- Pet alert no longer search a pet for mages
- Pet alert no longer search pet for MM Hunters

### New feature
- Group check
  - Group check allow you to have an additional window when joining a group or raid containing ilvls and buff coverage

## v0.3.1
- Adding 12.0.5 version as available for this addon
- Revamped buff check module
  - multiple buff added to buff check
  - new check incoming soon

## v0.3.0
- Global refactor (AI Assisted)
- Kaldotv_tweaks is now available on Github

## v0.2.4
### Fixes
- getKnownRacialSpellID is now a real function to avoid any unexpected behavior
- revamped config UI to prevent some interface breaks
- /kaldo is now blocked when the player is on combat mode and will wait for the combat to be over

### Enhancement
- Median ilvl is now managed by KaldoTweaks too, and display a decimal ilvl with the same color code as all items
- Median ilvl is now clearer when you inspect people, and follow the same color code as all items

## v0.2.3
### New feature : Auto potion
- Create a new macro "KaldoPotion"
  - This macro cycle around your healing options
  - /!\ Icon and tooltip will always be the first item (Blizzard limitation), so you may need to track your needed cooldown externally

## v0.2.2
### Preseason update
- Adjusted ilvl tresholds display for preseason

## v0.2.1
### Enhancement
#### Hunter macro
Misdirection is now smarter, and will target by default in this order, in a fallback model :
- Focus
- Tank
- Target
- Pet

#### No more self target
- Macro will now try to ignore the player and will target another healer or tank if possible

## V0.2.0
### Midnight pre release update
#### Equipement info
- New item level treshold (force updated), based on max level for crafted items in champion, hero, myth:
  - Very low ilvl under 259
  - Low ilvl 272
  - Medium ilvl under 285
  - High ilvl for 285 and more
- These tresholds can still be updated from the /kaldo menu
- Change the max ilvl on config from 200 to 350
- Updated the enchanted slot to reflect available enchantments available at midnight
- Updated the number of sockets to reflect available sockets avaible at midnight

#### Auto Macro feature
New feature to help user by creating macro autoupdated for dungeon groups

- Moved Tank Automarker to this new section
- Added automacro options for the following spells
  - Shaman : Earth Shield
  - Hunter : Misdirection
  - Rogue : Tricks of the Trade
  - Evoker : Source of Magic
  - Evoker : Blistering Scales
    - A macro combining the two buff for evokers is available aswell

## v0.1.6-beta
### Fixes
- Disabled buff check during MM+ keys
- Removed debug mode options
- Purge LFG cache to avoid misleading messages when joining a new group

## v0.1.5-beta
### New features
- Create a Macro to automark tanks in dungeon groups
- Remind on which group you applied on LFG when you join a group

## v0.1.4-beta
### Fixes
- New attempt to fix the crash when people are talking in party channel during a MM+ dungeon
- Inventory ilvl is now refresh when an item/gem/enchant changes, without the need to close/open the tab

## v0.1.3-beta
### Fix
- MM Key module should no longer try to read chat during a MM+ run

## v0.1.2-beta
- Fix : MM+ chat scan is now disabled during MM+