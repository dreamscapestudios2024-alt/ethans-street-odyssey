class_name VeniceBeachLayout
extends RefCounted
## Hand-authored Stage 1 street sequence. Edit freely: lengths are in pixels.

const T := StreetModule.Type

static func layout() -> Array:
	return [
		{"type": T.SIDEWALK, "length": 1800.0},                         # warm-up: push, cruise
		{"type": T.GARDEN_BED, "length": 520.0},                        # jump up onto it
		{"type": T.SIDEWALK, "length": 700.0},
		{"type": T.RAMP_UP, "length": 360.0},                           # kicker
		{"type": T.SIDEWALK, "length": 1000.0},
		{"type": T.HANDRAIL, "length": 760.0},                          # 50-50 grind
		{"type": T.SIDEWALK, "length": 800.0},
		{"type": T.POTHOLE},                                            # hazard: jump it
		{"type": T.SIDEWALK, "length": 700.0},
		{"type": T.BARRIER},                                            # jump or crash
		{"type": T.SIDEWALK, "length": 600.0},
		{"type": T.LEDGE, "length": 900.0},                             # second grind
		{"type": T.SIDEWALK, "length": 500.0},
		{"type": T.STAIRS_RAIL, "step_count": 6},                       # descending stairs + rail
		{"type": T.SIDEWALK, "length": 1400.0},
		{"type": T.BRICK_WALL, "length": 420.0},
		{"type": T.SIDEWALK, "length": 600.0},
		{"type": T.BIN},
		{"type": T.SIDEWALK, "length": 1200.0},
		{"type": T.RAMP_DOWN, "length": 360.0},
		{"type": T.SIDEWALK, "length": 2400.0},
	]
