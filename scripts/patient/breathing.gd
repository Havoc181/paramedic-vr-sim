extends RefCounted
## Breath cycle generator. Call step(delta) each frame; read `value`
## (0 = end of exhale, 1 = end of inhale) and `inhaling`.

signal breath_started

var rate := 16.0           ## breaths per minute
var inhale_fraction := 0.4 ## share of each breath spent breathing in
var variability := 0.08    ## random spread in breath length (0.08 = +/-8%)

var value := 0.0
var inhaling := true
var _phase := 0.0
var _period := 3.75

## Length of the current breath in seconds.
var period: float:
	get:
		return _period


func _init(breaths_per_minute := 16.0) -> void:
	rate = breaths_per_minute
	_phase = randf()
	_new_period()


func step(delta: float) -> void:
	_phase += delta / _period
	if _phase >= 1.0:
		_phase -= 1.0
		_new_period()
		breath_started.emit()
	if _phase < inhale_fraction:
		inhaling = true
		value = smoothstep(0.0, 1.0, _phase / inhale_fraction)
	else:
		inhaling = false
		var t := (_phase - inhale_fraction) / (1.0 - inhale_fraction)
		# Exhale falls quickly at first, then tails off.
		value = 1.0 - sqrt(clampf(t, 0.0, 1.0))


func _new_period() -> void:
	_period = 60.0 / maxf(rate, 1.0) * randf_range(1.0 - variability, 1.0 + variability)
