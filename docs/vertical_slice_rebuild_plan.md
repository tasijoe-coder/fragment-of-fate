# Fragment of Fate Vertical Slice Rebuild Plan

## Current Reality
- Local repo is effectively empty: there is no Godot project, no battle scripts, and no UI scene to rebuild from.
- The only local product guidance available right now is `AGENTS.md` plus the current battle architecture rules.
- Exact battle UI layout and animation spec are not present in the repo. Until those files are restored, implementation should stay visually neutral and focus on architecture, observability, and extension hooks.

## Demo Goal
- Deliver a playable single-battle vertical slice in Godot 4.
- Keep Combo / Attack Chain as the only promoted build path in the demo.
- Route every battle action through `BattleController -> RuleEvaluator -> apply_event_result()`.
- Make event flow visible enough to debug without stepping through code.

## Non-Negotiable Runtime Rules
1. Cards only request events.
2. `BattleController` is the only battle flow coordinator.
3. `RuleEvaluator` decides the outcome of requested events.
4. `apply_event_result()` is the only place that mutates `BattleState`.
5. Debug visibility is part of the slice, not a later polish step.

## Rebuild Order
1. Project bootstrap
   - Create a Godot 4 project entrypoint.
   - Add a single battle scene as the executable slice root.
2. Core battle runtime
   - Implement `BattleState`, `BattleEvent`, `RuleEvaluator`, and `BattleController`.
   - Keep the event queue synchronous and readable.
3. Demo battle data
   - Define a deterministic starter deck for Combo / Attack Chain.
   - Define one enemy with a fixed intent for fast validation.
4. Battle UI and observability
   - Add player/enemy status, hand interaction, end turn/reset controls, and an event log.
   - Add small feedback hooks for damage/combo resolution without inventing a new art direction.
5. Validation pass
   - Confirm the battle can be won/lost/reset.
   - Confirm all state writes happen in `apply_event_result()`.

## Done Criteria For This First Reconstruction Pass
- Godot opens the project without missing main-scene references.
- The demo battle starts from a clean reset path.
- Playing a card produces an event, resolves through `RuleEvaluator`, and writes through `apply_event_result()`.
- Combo count visibly affects attack damage.
- End turn resolves enemy intent and starts the next player turn.
- Event log and state snapshot make the battle flow inspectable.

## Known Gap
- If the previously defined UI / animation spec exists outside this repo, it still needs to be restored into source control before the presentation layer can be matched exactly.
