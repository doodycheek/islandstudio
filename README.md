# Island Studio

Customizes the Dynamic Island with a Live Activity, plus a background keep-alive so animations keep running.

## v1.5
- Default preset, Save as new / Update / Duplicate / Favorites / Surprise me
- Colors: accent synced to time of day, battery, weather or album art; slots that follow the accent; palettes; colors from a photo; app theme can match the island
- Per-slot size, nudge, shape, 3-color gradients with angle, motion (bounce, wiggle, float, flip...), font weight/width/spacing, glow strength
- Rules ("if raining → preset") and shuffle, custom long-press buttons incl. Apple Music controls, photo slideshow
- Expanded: layouts, title color and icon. Lock Screen: gradient/custom backgrounds, badge styles, chip picker, progress bar styles

## v1.4
- Previews no longer show the charging layout; charging look is now optional
- Real battery glyph (green charging, red low), live weather icons in natural colors
- Island background (tint / gradient), tap counter, focus timer, days counter, moon, crypto, world clock, rotating messages
- Low battery + headphone pop-outs, holiday and birthday presets, Island Clock home screen widget, backup code

## v1.3
- New app layout: Studio / Presets / Settings tabs with card-style screens
- Preview tabs now control which settings you see (Island, Expanded, Lock Screen)
- Themes: System / Light / Dark plus 8 accent colors
- Neon glow, 3 Lock Screen layouts, own Lock Screen text, info chips + accent bar in the expanded view
- 14 new presets in categories, music layout that keeps your own preset's minimal bubble

## v1.2
- UI overhaul: live preview pinned at the top of every screen (Island / Expanded / Lock Screen)
- Redesigned Lock Screen: Tinted / Black / Glass, info chips, animated accent bar
- When music plays: keep island, show the music, or let music take over

## v1.1
- Live info: Now Playing (Apple Music), album art, music bars, steps, weather, countdown
- Animations: scrolling text, charging mode + charging bar, gradients, color cycling, hourly pop-out
- Island buttons (previous / pause / next) in the long-press view
- Shortcuts actions: Start, Stop, Set Preset, Next/Previous Preset, Pause/Resume
- Save your own presets, share them as codes, and auto-switch by time of day

## Build (GitHub Actions)
Push to main, or Actions → Build IPA → Run workflow. Download the IslandStudio-ipa artifact.

## Feather
Don't remove PlugIns/extensions. Keep the bundle ID the same so it installs as an update.
