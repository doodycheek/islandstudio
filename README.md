# Island Studio

Customizes what shows in the Dynamic Island using a Live Activity, with a
background keep-alive so animations keep running.

## Build on Windows (GitHub Actions)
1. Create a new repo on github.com.
2. Upload EVERYTHING in this folder (including the `.github` folder) to the repo.
3. Go to the **Actions** tab → **Build IPA** → **Run workflow**.
4. When it finishes (~5 min), open the run and download **IslandStudio-ipa**.
5. Unzip it to get `IslandStudio.ipa`, then import into Feather and sign.

## Feather tips
- Don't enable any option that removes PlugIns/extensions (the island lives in one).
- Keep the original bundle ID if you can.

## On the phone
- Open the app, pick a style, tap **Start island**.
- Leave "Keep running in background" on, and don't swipe the app away.
