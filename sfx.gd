extends Node
## Sound effects and background music synthesized in code, no audio files.

const RATE := 22050
const MUSIC_RATE := 16000
const NOTE := {"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0,
	"A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0,
	"A4": 440.0, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.26, "G5": 783.99, "A5": 880.0}
const CHORDS := [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"]]
const ARP := [["A4", "C5", "E5", "C5"], ["A4", "C5", "F4", "C5"], ["G4", "C5", "E5", "C5"], ["G4", "B4", "D5", "B4"]]
const MUSIC_BAR := 4.0

var enabled := true
var _sounds := {}
var _players: Array = []
var _music: AudioStreamPlayer
var _next := 0
var _music_data := PackedByteArray()
var _music_i := -1  # next music sample to build, -1 when done


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -13.0
	add_child(_music)
	_sounds = {
		"hit": _make(0.12, func(t): return _noise() * _env(t, 0.12, 0.002) * 0.5 + sin(TAU * 90.0 * t) * _env(t, 0.12, 0.002) * 0.6),
		"crit": _make(0.22, func(t): return _noise() * _env(t, 0.22, 0.001) * 0.6 + _square(lerpf(900.0, 200.0, t / 0.22), t) * _env(t, 0.22, 0.001) * 0.25),
		"heal": _make(0.45, func(t): return _chime([NOTE["C5"], NOTE["E5"], NOTE["G5"]], t, 0.12) * 0.45),
		"shield": _make(0.35, func(t): return sin(TAU * lerpf(220.0, 330.0, t / 0.35) * t) * _env(t, 0.35, 0.05) * 0.5),
		"ult": _make(0.7, func(t): return (_noise() * 0.35 + sin(TAU * lerpf(200.0, 900.0, t / 0.7) * t) * 0.4) * _env(t, 0.7, 0.08)),
		"victory": _make(1.1, func(t): return _chime([NOTE["C4"], NOTE["E4"], NOTE["G4"], NOTE["C5"]], t, 0.14) * 0.55),
		"defeat": _make(1.0, func(t): return _chime([NOTE["A3"], NOTE["F3"], NOTE["D3"]], t, 0.22) * 0.5),
		"click": _make(0.05, func(t): return sin(TAU * 1400.0 * t) * _env(t, 0.05, 0.001) * 0.3),
	}
	# Music is built a slice per frame so the game never freezes on start.
	_music_data.resize(int(MUSIC_BAR * CHORDS.size() * MUSIC_RATE) * 2)
	_music_i = 0


func _process(_delta: float) -> void:
	if _music_i < 0:
		return
	var n := _music_data.size() / 2
	var end := mini(n, _music_i + 4000)
	for i in range(_music_i, end):
		_music_data.encode_s16(i * 2, int(clampf(_music_sample(float(i) / MUSIC_RATE), -1.0, 1.0) * 30000.0))
	_music_i = end
	if _music_i >= n:
		_music_i = -1
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = MUSIC_RATE
		s.data = _music_data
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
		_music.stream = s
		if enabled:
			_music.play()


func play(name: String) -> void:
	if not enabled or not _sounds.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = randf_range(0.94, 1.06) if name == "hit" else 1.0
	p.play()


func set_enabled(on: bool) -> void:
	enabled = on
	if on and not _music.playing and _music.stream:
		_music.play()
	elif not on:
		_music.stop()


# --- Synthesis helpers ---

func _make(length: float, fn: Callable, rate: int = RATE) -> AudioStreamWAV:
	var n := int(length * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(fn.call(float(i) / rate), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


## Attack-decay envelope that ends at zero.
func _env(t: float, length: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / (length - attack), 2.0)


## Notes struck one after another, each ringing out.
func _chime(notes: Array, t: float, step: float) -> float:
	var v := 0.0
	for i in notes.size():
		var start := i * step
		if t >= start:
			var lt := t - start
			v += (sin(TAU * notes[i] * lt) + 0.3 * sin(TAU * notes[i] * 2.0 * lt)) * exp(-lt * 5.0)
	return v / 2.0


## A calm 16-second loop: soft pad chords with a plucked arpeggio (Am - F - C - G).
func _music_sample(t: float) -> float:
	var ci := int(t / MUSIC_BAR) % CHORDS.size()
	var bt := fmod(t, MUSIC_BAR)
	var v := 0.0
	var swell := sin(PI * bt / MUSIC_BAR) * 0.8 + 0.2
	for nm in CHORDS[ci]:
		var f: float = NOTE[nm]
		v += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * 0.11 * swell
	v += sin(TAU * NOTE[CHORDS[ci][0]] * 0.5 * t) * 0.12
	var lt := fmod(bt, 0.5)
	var f2: float = NOTE[ARP[ci][int(bt / 0.5) % 4]]
	v += (sin(TAU * f2 * lt) + 0.4 * sin(TAU * f2 * 3.0 * lt) * exp(-lt * 12.0)) * exp(-lt * 6.0) * 0.22
	return v
