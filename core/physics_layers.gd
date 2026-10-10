class_name PhysicsLayers
extends RefCounted
## Collision layer bits shared by every system. Names are mirrored in
## Project Settings > Layer Names > 3D Physics.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const PICKUP := 1 << 3
