---
name: territory-conquest-idle-dev
description: Project-specific workflow for building and iterating Territory Conquest Idle in this repository. Use when planning, scaffolding, implementing, testing, balancing, documenting, or preparing original art prompts for the Godot 4.3 portrait mobile roguelite project, especially when changing agent.md, image_prompts.md, project.godot, scenes/, scripts/, data/, assets/, or tests/ while preserving deterministic simulation and IP-safe asset rules.
---

# Territory Conquest Idle Dev

## Overview

- Treat `agent.md` as the source of truth for architecture, mechanics, pacing, formulas, asset scope, and validation gates.
- Treat `image_prompts.md` as the source of truth for original art generation batches.
- Default stack to Godot 4.3, GDScript, portrait mobile layout, data-driven JSON content, and deterministic gameplay logic.

## Start Here

1. Inspect the repository tree before changing anything.
2. Read the relevant sections of `agent.md` before implementation.
3. Read `image_prompts.md` only when working on art generation or asset inventory synchronization.
4. If the project scaffold is incomplete, follow the build order in Section 19 of `agent.md`.

## Development Workflow

1. Implement the smallest shippable vertical slice first.
2. Keep pure simulation logic separate from scene and UI code.
3. Put balance values in `data/*.json`, not scattered scene scripts.
4. Preserve deterministic behavior for map generation, combat formulas, and rewards.
5. Run the smallest relevant validation immediately after each change.
6. Leave safe stubs behind incomplete systems instead of half-integrated broken code.

## Build Order

- Bootstrap in this order: `project.godot` -> autoloads -> `data/` -> home flow -> run flow -> combat math -> result/meta flow -> tests.
- Use `agent.md` Section 17 to stay inside the current phase.
- Update docs before code when architecture, scope, formulas, or asset requirements change.
- Update `agent.md` and `image_prompts.md` together when asset filenames or counts change.

## File Rules

- Put scene files in `scenes/`.
- Put gameplay and service logic in `scripts/`.
- Put JSON definitions in `data/`.
- Put automated checks in `tests/`.
- Keep filenames and IDs in `snake_case`.
- Preserve the 20 top-level sections in `agent.md` when editing it.
- Keep `image_prompts.md` in 5-image batches unless the user explicitly changes batching.

## Validation

- Run boot validation with `godot4 --headless --path . --quit` when Godot CLI is available.
- Run automated checks with `godot4 --headless --path . --script res://tests/test_runner.gd` when Godot CLI is available.
- Test map changes against multiple seeds and no-soft-lock conditions.
- Test combat changes with fixed stat snapshots and deterministic expected outputs.
- Test save changes with serialize-load-restore checks.
- If Godot CLI is unavailable, state that explicitly and perform static validation plus file-structure review.

## Art and IP Safety

- Generate only original, commercially safe assets.
- Do not reference or imitate existing games, characters, franchises, studios, brands, logos, or named artist styles.
- Reject outputs with text, watermark, signature, logo, or real-person likeness.
- Regenerate any asset that resembles known IP.
- Keep asset filenames synchronized across `agent.md`, `image_prompts.md`, and the repository.

## Document Sync

- Update `agent.md` when mechanics, architecture, asset scope, validation rules, or development phases change.
- Update `image_prompts.md` when any asset is added, removed, renamed, or re-batched.
- Keep the asset count and prompt count synchronized after every asset-related change.
- Re-check batch count after editing `image_prompts.md`.

## Do Not

- Do not treat the preinstalled web match-3 skills as authoritative for this project.
- Do not hardcode the same balance value in multiple scripts.
- Do not combine monetization work with unrelated gameplay refactors in the same pass.
- Do not import non-original art into `assets/`.
- Do not leave placeholder markers in final project docs, prompts, or skill files.
