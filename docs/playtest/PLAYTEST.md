# PRISM prototype playtest kit

For the facilitator running the M7 playtest (GDD §10 M7, §13). One session per participant, about 45 minutes.

## What we need to learn

The prototype is done when (GDD §13):

1. A first-time user finishes tasks T1–T6 below **unaided in under 15 minutes in total**.
2. No data loss (covered by the soak test, `bench/soak.gd`, but note any lost work you see).
3. Performance budgets are met on the reference machine (covered by `bench/budgets_bench.gd`).
4. Average ratings of **≥ 4 / 5** for "feels like DPaint" and "feels like a modern sprite tool".

## Participants (3–5)

| Profile | Why | Count |
|---|---|---|
| Deluxe Paint / Amiga veteran | Judges the DPaint feel (brush pickup, stencil, cycling, two-handed palette) | 1–2 |
| Daily Aseprite user | Judges the timeline, layers, onion skin, export | 1–2 |
| Indie game developer (Godot preferred) | Judges sprite sheet / SpriteFrames export into a game | 1 |

## Before each session

- [ ] Latest build, or `godot --path .` from the repo at the tagged commit.
- [ ] Fresh preferences: delete `user://settings.cfg`, `user://keybindings.json` and `user://autosave/`
      (macOS: `~/Library/Application Support/Godot/app_userdata/prism/`).
- [ ] Key preset: **Modern** for Aseprite users, offer **Classic** (Project → Preferences) to DPaint veterans.
- [ ] Screen + audio recording on (with consent). Timer ready.
- [ ] A 16-color palette file to hand out (or use Picture → Palette: PICO-8 style 16).
- [ ] Empty folder for exports; for the game developer, a Godot 4.7 project to export into.

## Facilitator rules

- Read each task aloud, then stay quiet. Ask the participant to think aloud.
- Do not help unless they are stuck for **2 minutes**. Then give the smallest hint and mark the task **assisted**.
- Write down every hesitation, wrong guess, error message and "huh?" with the time.
- Time each task from "go" to the participant saying "done".

## Task script

Total target: **15 minutes** for T1–T6, unaided.

| # | Task (read aloud) | Target | Done when | Watch for |
|---|---|---|---|---|
| T1 | "Create a 32×32 image and load a 16-color palette. Draw a small character." | 4 min | A recognizable character on a 32×32 canvas with a 16-color palette | Finding New and palette presets/Load; LMB/RMB = FG/BG; `[` `]` stepping; pixel-perfect pencil; zoom and pan |
| T2 | "Pick up the character's head as a brush and stamp it three times, one of them flipped." | 2 min | Three stamps, one mirrored | Discovering `B`; the ghost preview; `X` / `Y` to flip; `Shift+B` to go back to a normal brush |
| T3 | "Shade the character with Shade mode, but don't let the outline color change." | 3 min | Visible shading, outline untouched | Finding Mode → Shade; ramps (needs a ramp covering the colors); Ctrl/Cmd+click to lock the outline; the orange flash on blocked pixels |
| T4 | "Make a 4-frame idle animation using onion skin, tag it `idle` and play it." | 3 min | Tag `idle` over 4 frames, playing | Alt+D / Alt+N; Onion button / F3; +Tag and naming; Enter to play |
| T5 | "Add a color cycle so the eyes glint, then export a GIF with the cycling baked in." | 2 min | A GIF in which the eyes glint | Cycle FG→BG; Tab to preview; Export GIF → "Bake color cycling" |
| T6 | "Export a sprite sheet with JSON, and save the project." | 1 min | `.png` + `.json` + `.prism` on disk | Export sprite sheet; Save / Save as; the `*` in the title disappearing |

Game developer only (extra, not timed): "Export Godot SpriteFrames into your project and play `idle` on an AnimatedSprite2D."

## After the tasks: questionnaire

Ask the participant to answer on paper or in a form. 1 = strongly disagree, 5 = strongly agree.

| # | Statement | 1–5 |
|---|---|---|
| Q1 | **PRISM feels like Deluxe Paint.** | |
| Q2 | **PRISM feels like a modern sprite tool.** | |
| Q3 | I always knew what my mouse click would paint (brush, color, mode). | |
| Q4 | Undo did what I expected. | |
| Q5 | The timeline (layers × frames, tags) was easy to understand. | |
| Q6 | I could find export options for my use (GIF, sheet, Godot). | |
| Q7 | I would use PRISM for a real project. | |

Open questions:

1. What was the most frustrating moment?
2. What did you enjoy most?
3. Which missing feature would stop you from using PRISM?
4. (DPaint veterans) Which DPaint habit did PRISM break?
5. (Aseprite users) What did you expect from Aseprite that was missing or different?

## Observer log (one per session)

```
Participant: P_   Profile: __________   Key preset: Modern / Classic   Date: ____

| Task | Start | End | Minutes | Unaided? | Notes (hesitations, errors, quotes, time) |
|------|-------|-----|---------|----------|-------------------------------------------|
| T1   |       |     |         |          |                                           |
| T2   |       |     |         |          |                                           |
| T3   |       |     |         |          |                                           |
| T4   |       |     |         |          |                                           |
| T5   |       |     |         |          |                                           |
| T6   |       |     |         |          |                                           |
Total T1–T6: ____ min      Lost work seen? yes / no      Crashes? ____
```

## Results summary (fill in after all sessions)

| Participant | Profile | T1–T6 minutes | All unaided? | Q1 DPaint | Q2 Modern | Q3 | Q4 | Q5 | Q6 | Q7 |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | | | | | | | | | | |
| P2 | | | | | | | | | | |
| P3 | | | | | | | | | | |
| **Average** | | | | **≥ 4?** | **≥ 4?** | | | | | |

## Triage

Turn every observation into one line, then sort.

| Severity | Meaning | Goes to |
|---|---|---|
| S1 — blocker | A task could not be finished, data was lost, or a crash | Fix before calling the prototype done |
| S2 — major | Finished only with a hint, or > 2× target time | Top of the P1 backlog |
| S3 — minor | Hesitation or annoyance, finished unaided | P1 backlog, ordered by how many participants hit it |
| S4 — idea | Feature request or suggestion | Post-prototype backlog (`TODO.md`) |

```
| ID | Severity | Seen by (P1..P5) | Task | Observation | Proposed change | Backlog item |
|----|----------|------------------|------|-------------|-----------------|--------------|
```

Questions this playtest should also settle (GDD §12):

- **Q1:** should Shade wrap at the ends of a ramp, or clamp (current default)?
- **Risk 3:** which key preset should be the default, Classic or Modern?
- Onion skin drawn in front (current default) or behind?
