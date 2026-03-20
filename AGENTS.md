# Project: Fragment of Fate

## Engine
Godot 4 (2D)

## Core Concept
A roguelike deckbuilder focused on "rule editing".

Players construct rule chains:
Condition -> Action -> Result

This system is called the "Fate Board".

## Design Philosophy
- This is NOT a traditional deckbuilder
- Cards are tools to trigger rule chains
- The core gameplay is building rule logic, not just playing cards

## Development Principles
- Prioritize playable prototype
- Systems must be debuggable
- Use data-driven design
- Avoid over-engineering
- All systems must support the rule engine

## Current Phase
Phase 0 → Phase 1:
- Project setup
- Basic battle system
- Rule system will be added in Phase 2

## Important Rules
- Do NOT add unnecessary systems
- Do NOT overbuild architecture
- Keep implementation minimal but extensible
- Always prefer clarity over cleverness
