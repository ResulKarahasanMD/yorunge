"""Writes levels/tutorial_0{1,2,3}.tscn from compact layout specs and checks gaps.

Usage (from the project root; needs numpy):
    python3 tools/gen_tutorials.py .

The three tutorial scenes in the repository are exactly this script's output
(byte-identical, checked 2026-10-11). Running it OVERWRITES them: edit the
layouts below rather than the scenes, and close the scenes in the Godot editor
first (an open scene is saved back over files written from outside).
Gap check: linked planets <= 7.2 m (MAX_GAP 9 m x 0.8), others > 9 m, none < 2 m.
"""
import sys, pathlib, numpy as np

ROOT = pathlib.Path(sys.argv[1])
DESIGN_GAP = 9.0 * 0.8
STYLE = {"grass": "res://world/styles/grass.tres", "ice": "res://world/styles/ice.tres",
         "lava": "res://world/styles/lava.tres", "moon": "res://world/styles/moon.tres"}

def n(v): v = np.array(v, float); return v / np.linalg.norm(v)

def place(planets, name, style, radius, parent=None, direction=None, gap=None, spin=0.0, axis=(0.3, 1, 0.2)):
    if parent is None:
        center = np.zeros(3)
    else:
        p = planets[parent]
        center = p["center"] + n(direction) * (p["radius"] + gap + radius)
    planets[name] = dict(name=name, style=style, radius=radius, center=center, spin=spin, axis=axis, parent=parent, gap=gap)

def fmt(v): return ", ".join(f"{x:.4g}" for x in v)

def basis_rows(up, forward_hint=(0, 0, -1)):
    y = n(up); f = np.array(forward_hint, float); f = f - y * f.dot(y)
    if np.linalg.norm(f) < 1e-3: f = np.cross(y, [1, 0, 0])
    f = n(f); z = -f; x = np.cross(y, z)
    m = np.column_stack([x, y, z])
    return list(m[0]) + list(m[1]) + list(m[2])

def check(level):
    planets = level["planets"]; names = list(planets)
    print(f"== {level['id']}")
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            pa, pb = planets[a], planets[b]
            gap = np.linalg.norm(pa["center"] - pb["center"]) - pa["radius"] - pb["radius"]
            linked = pb["parent"] == a or pa["parent"] == b
            flag = ""
            if gap < 2.0: flag = "  !! OVERLAP/TOO CLOSE"
            elif linked and gap > DESIGN_GAP: flag = "  !! LINK GAP > DESIGN"
            elif not linked and gap <= 9.0: flag = "  (extra link)"
            print(f"  {a:8} - {b:8} gap {gap:6.2f}{' link' if linked else ''}{flag}")

def write(level):
    ext = [("Script", "res://levels/level.gd"), ("PackedScene", "res://world/planet.tscn"),
           ("PackedScene", "res://player/player.tscn"), ("PackedScene", "res://camera/camera_rig.tscn"),
           ("PackedScene", "res://world/space_backdrop.tscn"), ("PackedScene", "res://world/stardust.tscn"),
           ("PackedScene", "res://world/exit_portal.tscn"), ("PackedScene", "res://world/spike_ball.tscn"),
           ("Script", "res://levels/tutorial_hints.gd"), ("Script", "res://levels/tutorial_hint.gd")]
    styles = sorted({p["style"] for p in level["planets"].values()})
    ext += [("Resource", STYLE[s]) for s in styles]
    ids = {path: f"{i + 1}_r" for i, (_, path) in enumerate(ext)}
    out = ["[gd_scene format=3]", ""]
    for kind, path in ext:
        out.append(f'[ext_resource type="{kind}" path="{path}" id="{ids[path]}"]')
    out.append("")
    for i, (text, trig) in enumerate(level["hints"]):
        out += [f'[sub_resource type="Resource" id="Hint_{i}"]', f'script = ExtResource("{ids["res://levels/tutorial_hint.gd"]}")',
                f'text = "{text}"', f"trigger = {trig}", ""]
    root = level["node"]
    out += [f'[node name="{root}" type="Node3D" node_paths=PackedStringArray("player", "camera_rig")]',
            f'script = ExtResource("{ids["res://levels/level.gd"]}")', f'level_id = "{level["id"]}"',
            f'level_title = "{level["title"]}"', 'player = NodePath("Player")', 'camera_rig = NodePath("CameraRig")', "",
            f'[node name="SpaceBackdrop" parent="." instance=ExtResource("{ids["res://world/space_backdrop.tscn"]}")]', "",
            '[node name="Planets" type="Node3D" parent="."]', ""]
    for p in level["planets"].values():
        out += [f'[node name="{p["name"]}" parent="Planets" instance=ExtResource("{ids["res://world/planet.tscn"]}")]',
                f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {fmt(p["center"])})',
                f'radius = {p["radius"]}', f'style = ExtResource("{ids[STYLE[p["style"]]]}")']
        if p["spin"]:
            out += [f'spin_axis = Vector3({fmt(n(p["axis"]))})', f'spin_speed_deg = {p["spin"]}']
        out.append("")
    for i, (planet, d) in enumerate(level["stardust"]):
        out += [f'[node name="Stardust{i + 1}" parent="Planets/{planet}" instance=ExtResource("{ids["res://world/stardust.tscn"]}")]',
                f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {fmt(n(d))})', ""]
    planet, d, heading = level["portal"]
    out += [f'[node name="ExitPortal" parent="Planets/{planet}" instance=ExtResource("{ids["res://world/exit_portal.tscn"]}")]',
            f'transform = Transform3D({fmt(basis_rows(d, heading))}, {fmt(n(d))})', ""]
    for i, (planet, axis, start, speed) in enumerate(level.get("enemies", [])):
        out += [f'[node name="SpikeBall{i + 1}" parent="Planets/{planet}" instance=ExtResource("{ids["res://world/spike_ball.tscn"]}")]',
                f'patrol_axis = Vector3({fmt(n(axis))})', f'start_direction = Vector3({fmt(n(start))})', f'patrol_speed_deg = {speed}', ""]
    sp, sd = level["spawn"]
    p = level["planets"][sp]
    origin = p["center"] + n(sd) * (p["radius"] + 0.05)
    out += [f'[node name="Player" parent="." instance=ExtResource("{ids["res://player/player.tscn"]}")]',
            f'transform = Transform3D({fmt(basis_rows(sd))}, {fmt(origin)})', "",
            f'[node name="CameraRig" parent="." instance=ExtResource("{ids["res://camera/camera_rig.tscn"]}")]', "",
            '[node name="Hints" type="Node" parent="."]', f'script = ExtResource("{ids["res://levels/tutorial_hints.gd"]}")',
            "hints = [" + ", ".join(f'SubResource("Hint_{i}")' for i in range(len(level["hints"]))) + "]", ""]
    (ROOT / "levels" / f'{level["id"]}.tscn').write_text("\n".join(out))

# Trigger ids: START 0, MOVED 1, JUMPED 2, PLANET_CHANGED 3, STARDUST 4, PORTAL_OPEN 5, DAMAGED 6, ENEMY_DEFEATED 7
levels = []
pl = {}
place(pl, "Meadow", "grass", 10.0)
place(pl, "Pebble", "grass", 5.0, "Meadow", (0.75, 0.35, -0.56), 3.5)
levels.append(dict(id="tutorial_01", node="Tutorial01", title="1 · İlk Adımlar", planets=pl,
    stardust=[("Meadow", (0, 0.55, -1)), ("Meadow", (1, 0.15, 0.25)), ("Meadow", (-1, 0.2, -0.1)),
              ("Meadow", (0.15, -1, 0.3)), ("Pebble", (0.6, 0.6, -0.5))],
    portal=("Meadow", (-0.35, -0.5, 0.8), (1, 0, 0)), spawn=("Meadow", (0, 1, 0)),
    hints=[("Hoş geldin, kaşif! WASD / sol çubuk ile yürü, fareyle etrafına bak.", 0),
           ("Gezegenin her yanı yürünebilir; aşağısı hep merkez. Space / A ile zıpla.", 1),
           ("5 yıldız tozunu topla. Biri komşu küçük gezegende!", 2),
           ("Zıpladığında en güçlü çekim seni yakalar.", 3),
           ("Portal açıldı! Parlayan halkaya gir.", 5)]))
pl = {}
place(pl, "Home", "grass", 8.0)
place(pl, "Frost", "ice", 7.0, "Home", (1, 0, 0), 4.0)
place(pl, "Grove", "grass", 6.0, "Frost", (0.35, 0.15, -0.92), 5.0)
place(pl, "Crag", "moon", 5.0, "Grove", (-0.55, 0.35, -0.75), 4.5)
levels.append(dict(id="tutorial_02", node="Tutorial02", title="2 · Sıçrayış", planets=pl,
    stardust=[("Home", (0, 0.4, -1)), ("Frost", (0.3, 1, 0.4)), ("Frost", (0.4, -0.9, -0.3)),
              ("Grove", (0, 1, 0.2)), ("Crag", (-0.3, 0.8, -0.5))],
    portal=("Crag", (-0.2, -0.3, -1), (1, 0, 0)), spawn=("Home", (0, 1, 0)),
    hints=[("Komşu gezegene en yakın noktaya yürü ve zıpla: çekim seni karşıya taşır.", 0),
           ("Buz kaygandır! Erken fren yap, dikkatli dön.", 3),
           ("Her gezegende yıldız tozu var; hepsini topla.", 4),
           ("Portal açıldı! En uzaktaki kayalık gezegende.", 5)]))
pl = {}
place(pl, "Outpost", "grass", 9.0)
place(pl, "Cinder", "lava", 7.0, "Outpost", (1, 0, 0), 4.0)
place(pl, "Whirl", "moon", 4.0, "Cinder", (0.25, 0.1, -0.96), 3.5, spin=30.0)
place(pl, "Haven", "grass", 7.0, "Whirl", (-0.75, 0.15, -0.65), 4.5)
levels.append(dict(id="tutorial_03", node="Tutorial03", title="3 · Tehlike", planets=pl,
    stardust=[("Outpost", (-1, 0.2, 0.3)), ("Cinder", (0.2, 1, 0.2)), ("Cinder", (0.5, -0.6, -0.6)),
              ("Whirl", (0, 1, 0)), ("Haven", (0.3, 0.9, -0.3))],
    portal=("Haven", (-0.6, -0.2, -0.75), (0, 1, 0)), spawn=("Outpost", (0, 1, 0)),
    enemies=[("Outpost", (0, 1, 0), (1, 0, 0), 18.0), ("Haven", (1, 0, 0), (0, 1, 0), 20.0),
             ("Haven", (0, 0, 1), (1, 0, 0), 16.0)],
    hints=[("Dikenli kürelere yandan dokunma; üstlerine zıplayarak ez!", 0),
           ("Lav ısıtır: üstünde durma, zıplayarak ilerle. Dönen ayda dengede kal.", 3),
           ("Portal açıldı! Son gezegene koş.", 5)]))
for level in levels:
    check(level)
    write(level)
print("written:", [l["id"] for l in levels])
