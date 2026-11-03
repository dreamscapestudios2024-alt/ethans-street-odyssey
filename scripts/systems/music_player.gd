extends Node
## Persistent music + global audio-mute controller (autoload "Music"). Survives scene changes so the
## title song can carry on into the level. Muting silences the whole Master bus, so it covers the
## song and any sound effects added later. Missing tracks are ignored, so the game never fails without audio.

signal muted_changed(is_muted: bool)

const TITLE_TRACK := "res://assets/audio/ethan_at_the_curb.mp3"
const MUTE_ACTION := "mute"
const SETTINGS_PATH := "user://settings.cfg"

var player: AudioStreamPlayer
var muted := false
var _volume_db := 0.0
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	add_child(player)
	_load_preference()

## Starts a track (looping by default). Returns false if the file is not available.
func play_track(path: String, volume_db: float = 0.0, loop: bool = true) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("Music track not found: %s" % path)
		return false
	if player.playing and player.stream != null and player.stream.resource_path == path:
		fade_to(volume_db, 0.5)
		return true
	var stream := load(path) as AudioStream
	if stream == null:
		return false
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	player.stream = stream
	_volume_db = volume_db
	player.volume_db = volume_db
	player.play()
	return true

func ensure_playing() -> void:
	## Browsers only unlock audio after a user gesture; call this on the first key press / click.
	if player.stream != null and not player.playing:
		player.play()

func fade_to(volume_db: float, seconds: float = 1.0) -> void:
	_volume_db = volume_db
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", volume_db, seconds)

func set_muted(value: bool) -> void:
	var changed := value != muted
	muted = value
	_apply_mute()
	if changed:
		_save_preference()
		muted_changed.emit(muted)

## Mutes every sound in the game (Master bus); the music player's own volume is left alone.
func _apply_mute() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)

func _load_preference() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
	_apply_mute()

func _save_preference() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep any other settings
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)

func is_track_playing() -> bool:
	return player != null and player.playing

func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(MUTE_ACTION) and event.is_action_pressed(MUTE_ACTION):
		set_muted(not muted)
