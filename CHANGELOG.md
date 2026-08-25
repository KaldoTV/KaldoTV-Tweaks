v0.6.2
New feature
- MM Keys: added an option to hide stale Blizzard guild roster Mythic+ scores for members last seen before the current season
- Teleport buttons : Now display if the ability is on cooldown

v0.6.1
- Build fix

v0.6.0

New Features
- MM Keys: added optional regional and world Mythic+ score percentile estimates in the Challenges window
- Release builds now generate fresh Raider.IO percentile data and daily rebuilds publish dated build tags
- MM Keys: clicking a season-best dungeon tile now casts its dungeon teleport when the teleport is known

v0.5.2

Updates
- MM Keys: updated dungeon acronyms for Midnight Season 2

v0.5.1

New Features
- Auto Macros: added smart support for the Thalassian Master Repair Hammer
- Creates a `KaldoRepair` macro based on your real Midnight Blacksmithing specialization ranks
- Optional merchant auto-repair can now skip equipped slots that your hammer can repair for free

Fixes
- Improved equipped item repair detection when Blizzard returns partial durability data

v0.5.0
Updates
- Bump TOC to 11.1.0
- Update ilvl tresholds

v0.4.3
Fixes
- Removed the MM+ realm-language chat and group-frame feature
- Fixed repeated MMKeys errors caused by scanning protected group-frame children

v0.4.2
- Bump TOC version
- New options : MM+ > See realm language on chat or frames
- Update ilvl tresholds according to 12.0.7

v0.4.1
Fixes
- Pet presence is no longer checked in frost or blood specialization for DK

v0.4.0

New Features
- MM Keys: added a custom overlay on Mythic+ season-best dungeon tiles
- MM Keys: each tile can now display a dungeon acronym, best key level, score gained, and run timer
- MM Keys: added configurable font family and size options for acronym, level, score, and timer in `/kaldo`


v0.3.10

Fixes
- MM Key chat interactions are now more defensive: only strict `!key` / `!keys` messages are handled, suspicious chat payloads are ignored, self messages are ignored, and responses are rate-limited
- Group Ready now uses the actually equipped item level for the local player, which fixes mismatches caused by the previous average source
- Equipment info average item level now follows the same equipped-item-level source as Group Ready

Enhancements
- Equipment info gem quality checks now support socketed gem item IDs directly instead of relying only on tooltip text markers
- Equipment info gem/enchant rank logic now uses a max-rank whitelist model: any socketed gem or enchant not explicitly marked as max rank is treated as low rank
- Added current max-rank gem IDs for socket quality checks
- Enhance the lisibility of  buffs on the check group window

v0.3.9

Fixes
- Equipment info enchant rank detection is now based on enchant IDs instead of volatile tooltip names/text

v0.3.8

Fixes
- Prevent Blizzard updating the average player ilvl

Updates
- Update all ilvl thresholds for Equipment info to Midnight Season 1

v0.3.7

Fixes
- Fix range check looping on errors

v0.3.6

Fixes
- Buff checks now check if any valid target is in range

v0.3.5

Fixes
- Shaman: Flametongue enchantment is now searched in both main hand (Elemental) and off hand (Enhancement)
- Shaman: Tidecaller's Guard is no longer indicated as missing on Enhancement spec, as it's a passive spell

v0.3.4

Fixes
- Disable most of the buff check during Battleground because of secret values in auras

v0.3.3

Fixes
- Added a security to prevent MM+ module from reading chat during encounters (MM+, combat mode, BG)
- Enhance buff detection

New Features
- Group check: additional window when joining a group or raid containing ilvls and buff coverage

v0.3.2

Fixes
- Earth Shield (non personal version) is now searched on anyone in the group but the shaman instead of the tank only
- Fix a filter issue when "only my buff" is unticked
- Add a new fallback when in combat/MM+: when raid buffs are glowing, they are displayed as missing
- Added a new way to highlight my own buffs
- Pet alert no longer searches a pet for mages
- Pet alert no longer searches a pet for MM Hunters

v0.3.1

Updates
- Add 12.0.5 as available version for this addon
- Revamp buff check module
- Multiple buffs added to buff check
- New checks coming soon

v0.3.0

Updates
- Global refactor (AI assisted)
- Kaldotv_tweaks is now available on GitHub

v0.2.4

Fixes
- `getKnownRacialSpellID` is now a real function to avoid unexpected behavior
- Revamped config UI to prevent some interface breaks
- `/kaldo` is now blocked when the player is in combat and waits for combat to be over

Enhancements
- Median ilvl is now managed by KaldoTweaks too, and displays a decimal ilvl with the same color code as all items
- Median ilvl is now clearer when you inspect people, and follows the same color code as all items

v0.2.3

New Features
- Auto potion
- Create a new macro `KaldoPotion`
- This macro cycles around your healing options
- Icon and tooltip will always be the first item because of Blizzard limitations

v0.2.2

Updates
- Preseason ilvl threshold update

v0.2.1

Enhancements
- Hunter macro: Misdirection now targets by default in this fallback order: Focus, Tank, Target, Pet
- No more self target: macro now tries to ignore the player and target another healer or tank if possible

v0.2.0

Midnight Pre-release Update
- Equipment info: new item level thresholds based on crafted max level in champion, hero, myth
- Very low ilvl under 259
- Low ilvl 272
- Medium ilvl under 285
- High ilvl for 285 and more
- These thresholds can still be updated from the `/kaldo` menu
- Change the max ilvl in config from 200 to 350
- Updated enchanted slots to reflect available enchantments at Midnight
- Updated socket counts to reflect available sockets at Midnight

Auto Macro Feature
- New feature to help users by creating automatically updated macros for dungeon groups
- Moved Tank Automarker to this new section
- Added automacro options for the following spells:
- Shaman: Earth Shield
- Hunter: Misdirection
- Rogue: Tricks of the Trade
- Evoker: Source of Magic
- Evoker: Blistering Scales
- A macro combining the two buffs for Evokers is also available

v0.1.6-beta

Fixes
- Disabled buff check during MM+ keys
- Removed debug mode options
- Purged LFG cache to avoid misleading messages when joining a new group

v0.1.5-beta

New Features
- Create a macro to automark tanks in dungeon groups
- Remind which group you applied to on LFG when you join a group

v0.1.4-beta

Fixes
- New attempt to fix the crash when people are talking in party channel during a MM+ dungeon
- Inventory ilvl now refreshes when an item, gem, or enchant changes, without closing and reopening the tab

v0.1.3-beta

Fixes
- MM Key module should no longer try to read chat during a MM+ run

v0.1.2-beta

Fixes
- MM+ chat scan is now disabled during MM+
