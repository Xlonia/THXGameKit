# THXGameKit

**A danmaku (bullet-pattern) game creation kernel** for Godot 4.x (addon-style):
bullet runtime, character data handling, timelines and the danmaku editor live in
this kernel; concrete gameplay (auto-chess / STG / RPG / Roguelike) plugs in on top.

**First gameplay plugin**: [THX75](https://github.com/Xlonia/THX75)
(Touhou Xenothers: Keshinozoshiki) — a danmaku duel auto-chess.

> This README is a summary. The authoritative (Chinese) document is [README.md](README.md);
> Japanese: [README.ja.md](README.ja.md).

## Install

THX-series game repos reference this kernel as a **git submodule** (a pointer to a
commit, not a copy — that is why copying a game folder alone does not carry the kernel).

```bash
# attach the kernel to a game repo
git submodule add https://github.com/Xlonia/THXGameKit addons/thx_gamekit
# clone a game repo with the kernel
git clone --recurse-submodules <game repo>
git submodule update --init          # for already-cloned repos
# pull kernel updates inside a game repo
git submodule update --remote addons/thx_gamekit
```

No-submodule alternative: download this repo as ZIP and extract it into the game
project as `addons/thx_gamekit/` (identical behavior, manual upgrades).

## Status

**Data foundation v0 migrated** (2026-11-11): danmaku events / expressions /
textures / timelines / character table. Next migration step: the danmaku editor
and the entity core.

## What the kernel provides

- **Danmaku events in six motion types** (regular / physical / functed / nodes /
  nodes-B / laser), one official CSV table per type, plus a legacy single-file reader
- **Expression system** for nearly every danmaku field (time, fire-point index,
  focus-mode coefficient, target snapshots, character queries, RNG fields), with
  compile-time constant folding and a C++ accelerated evaluator (pure-GDScript fallback)
- **Fire gates**: random (rate) and pattern-pool (pattern) propositions
- **Character table (narrow core)**: key name, ZH/JA/EN names, focus/normal speed,
  fire-point layout & ratios; slot binding (main/sub/rest) and skill/spell timelines
- **Timeline** data (one tick per 0.1 s, stored as readable `.gd` text)
- **Danmaku editor** (required part of the kernel) with live trial-ground preview
- **.thx mod format**: zip (event tables + textures), overriding official data by name

## License

MIT — see [LICENSE](LICENSE).
