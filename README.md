# Kaldo Tweaks

`Kaldo Tweaks` is a lightweight World of Warcraft Retail addon focused on small quality-of-life improvements for group play, Mythic+, UI readability, and macro automation.

The addon is built as a modular toolbox:

- enable only the features you want
- keep CPU usage as low as possible
- avoid unnecessary UI clutter
- stay compatible with existing saved settings through versioned migrations

## Features

### Equipment Info

Adds item level and equipment status information directly on the character and inspect frames.

- item level overlay on equipped gear
- inspect item level display
- inspect average item level display
- socket checks
- enchant checks
- configurable fonts, sizes, thresholds, and colors

### Buff Check

Displays missing group buff reminders with configurable icons and highlight styles.

- supports common group buffs
- optional "only my buffs" mode
- configurable position, spacing, size, and highlight

### Pet Alert

Shows on-screen alerts when your pet is missing or dead, depending on class/spec configuration.

- separate dead/missing alerts
- per-alert font, color, sound, and position settings
- spec filtering

### Craft Order Alert

Detects system messages matching a configured text and shows an on-screen alert.

- configurable trigger text
- case sensitivity option
- throttle
- configurable text, font, color, sound, and position

### MM+ Keys

Adds a few Mythic+ quality-of-life helpers.

- auto-insert your keystone when relevant
- reply to `!key` / `!keys`
- accepted-group reminders

### Auto Macros

Creates or updates utility macros based on your current group composition and known spells.

- tank mark macro
- Evoker support macros
- Hunter Misdirection macro
- Rogue Tricks macro
- Shaman Earth Shield macro

### Auto Potion

Creates or updates a self-heal / potion macro based on available items, known spells, and per-character priority.

- auto-detects configured potions and healthstones
- supports class self-heals and supported racials
- per-character priority order

## Design Goals

`Kaldo Tweaks` is built around a few simple rules:

- modular first
- readable code
- backward-compatible saved variables
- restrained CPU usage
- practical UI improvements over flashy behavior

## Slash Commands

- `/kaldo` opens the addon settings
- `/kaldostatus` prints the current module status in chat

## Compatibility

- WoW Retail
- uses Blizzard Settings
- optional support for `LibSharedMedia-3.0`

## Notes

- Most modules are disabled by default.
- Settings are stored in `KaldoDB`.
- Existing saved variables are migrated automatically when needed.