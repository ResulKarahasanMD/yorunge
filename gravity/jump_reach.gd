class_name JumpReach
extends RefCounted
## Jump reach between planets with the default player tuning, measured by
## res://debug/physics_probe.tscn (headless sweep; numbers in PROGRESS.md).

## Largest surface-to-surface gap crossed in every probe run.
const MAX_GAP := 9.0
## Hand-made and generated levels keep gaps at or below this share of MAX_GAP.
const DESIGN_FACTOR := 0.8


static func design_gap() -> float:
	return MAX_GAP * DESIGN_FACTOR
