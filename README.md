# Filament

A phone puzzle for **Godot 4.2 or newer**. One hundred looms. Link each colored sigil to its twin. Threads cannot cross, and every ten looms add a rule.

| Looms | Chapter | New rule |
| --- | --- | --- |
| 1–10 | Kindling | Connect the twins. Empty tiles may stay dark. |
| 11–20 | Spool | Longer threads, less spare room. |
| 21–30 | Full Loom | Every tile must carry a thread. |
| 31–40 | Ash | Hatched tiles are dead. Fill every living tile. |
| 41–50 | Sluice | An arrow only lets a thread enter along its point. |
| 51–60 | Rails | Cross a rail straight. Turn when you leave a hook. |
| 61–70 | Beads | Visit that thread’s numbered beads in order. |
| 71–80 | Double Knot | Ash tiles, and no dark gaps left behind. |
| 81–90 | Counterweave | Arrows, rails, hooks, and beads together. |
| 91–100 | Masterwork | Every rule, on a wider loom. |

Tap or drag a sigil. Undo, Hint, and Reset sit under the board. A clean solve is three stars. One hint leaves two. More than that leaves one. Progress is saved in Godot’s user data folder.

## Open it in Godot

1. Install [Godot 4.2+](https://godotengine.org/download) (the standard build, not required to be .NET).
2. In the Project Manager, choose **Import**.
3. Browse to this folder and select `project.godot`.
4. Choose **Import & Edit**.
5. Press **F5** or the Play button.

The window is phone-shaped (390×844). Mouse drag in the editor matches a finger on a phone.

## Put it on a phone

1. **Editor → Manage Export Templates → Download and Install** (the templates must match your Godot version).
2. Install JDK 17 and the Android SDK, then point Godot at them under **Editor → Editor Settings → Export → Android**.
3. **Project → Install Android Build Template**.
4. **Project → Export… → Add… → Android**. Export format **APK**, not AAB.
5. **Export Project** (a debug keystore is enough for testing). Copy the APK to the phone and open it.

Android must use the Compatibility renderer. This project sets both **Rendering Method** and **Rendering Method.mobile** to `gl_compatibility`. If a phone build is a blank screen, those two were still on Vulkan: switch them under **Project → Project Settings → Rendering → Renderer**, then export the APK again. The 100 puzzles are stored in `scripts/levels_blob.gd` so they are packed into the APK.
