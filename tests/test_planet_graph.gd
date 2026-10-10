extends TestSuite
## PlanetGraph links, paths and hop counts.

func _layout() -> Dictionary:
	# 0 -(4 m)- 1 -(3.5 m)- 2 ; 0 -(6 m)- 3 ; 4 is out of reach of everyone.
	var centers := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(21, 0, 0), Vector3(32.5, 0, 0), Vector3(0, 0, -22), Vector3(200, 0, 0)])
	var radii := PackedFloat32Array([10, 7, 4, 6, 5])
	return {"centers": centers, "radii": radii}


func test_surface_gap() -> void:
	check_near(PlanetGraph.surface_gap(Vector3.ZERO, 10.0, Vector3(21, 0, 0), 7.0), 4.0, "gap between surfaces")
	check_near(PlanetGraph.surface_gap(Vector3.ZERO, 10.0, Vector3(15, 0, 0), 7.0), -2.0, "overlap is negative")


func test_links_respect_max_gap() -> void:
	var data := _layout()
	var links := PlanetGraph.build(data["centers"], data["radii"], JumpReach.MAX_GAP)
	check(Array(links[0]).has(1) and Array(links[0]).has(3), "0 links to 1 and 3")
	check(Array(links[1]).has(2) and not Array(links[1]).has(3), "1 links to 2, not to 3")
	check(links[4].is_empty(), "isolated planet has no links")
	var tight := PlanetGraph.build(data["centers"], data["radii"], 3.9)
	check(not Array(tight[0]).has(1), "4 m gap is not linked when max gap is 3.9")


func test_path_and_hops() -> void:
	var data := _layout()
	var links := PlanetGraph.build(data["centers"], data["radii"], JumpReach.MAX_GAP)
	check(Array(PlanetGraph.path(links, 3, 2)) == [3, 0, 1, 2], "3 -> 2 goes through 0 and 1")
	check(Array(PlanetGraph.path(links, 2, 2)) == [2], "path to self")
	check(PlanetGraph.path(links, 0, 4).is_empty(), "unreachable planet gives empty path")
	check(Array(PlanetGraph.hop_counts(links, 0)) == [0, 1, 2, 1, -1], "hop counts from 0")


func test_design_gap_below_max() -> void:
	check(JumpReach.design_gap() < JumpReach.MAX_GAP, "design gap leaves a margin")
	check_near(JumpReach.design_gap(), JumpReach.MAX_GAP * JumpReach.DESIGN_FACTOR, "design gap formula")
