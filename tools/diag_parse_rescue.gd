extends SceneTree
func _initialize():
    var targets = [
        "res://scripts/pawn/HeelKawnian.gd",
        "res://scenes/world/World.gd",
        "res://autoloads/JobManager.gd",
        "res://autoloads/PawnAccess.gd",
        "res://scripts/jobs/Job.gd",
    ]
    var fails = 0
    for t in targets:
        var scr = load(t)
        if scr == null:
            print("FAIL load null: %s" % t)
            fails += 1
        else:
            print("OK load: %s can_instantiate=%s" % [t, scr.can_instantiate()])
    if fails==0:
        print("PARSE_OK")
    else:
        print("PARSE_FAIL fails=%d" % fails)
    quit()
