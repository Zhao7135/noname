extends Node

var music:=AudioStreamPlayer.new()
var streams: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var voice_index:=0
var music_level:=.56
var fx_level:=.78
var random:=RandomNumberGenerator.new()

func prepare():
	add_child(music)
	var score:AudioStreamWAV=load("res://sound/cloud_garden.wav")
	score.loop_begin=0
	score.loop_end=roundi(score.get_length()*score.mix_rate)
	score.loop_mode=AudioStreamWAV.LOOP_FORWARD
	music.stream=score
	for k in ["step","timber","rock","ore","leaves","pickup","tap","no","fire","soil","eat","plank","water","sell","ready","build","level","island","treasure"]:
		streams[k]=load("res://sound/"+k+".wav")
	for i in 12:
		var p:=AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)
	set_levels(music_level,fx_level)
	music.play()

func set_levels(m:float,fx:float):
	music_level=clampf(m,0,1)
	fx_level=clampf(fx,0,1)
	music.volume_db=linear_to_db(maxf(.00001,music_level*.49))

func play(key:String,gain:=1.0,vary:=.055):
	if fx_level<=.001 or not streams.has(key):
		return
	var player=voices[voice_index]
	voice_index=(voice_index+1)%voices.size()
	player.stream=streams[key]
	player.pitch_scale=1+random.randf_range(-vary,vary)
	player.volume_db=linear_to_db(maxf(.00001,fx_level*gain*.55))
	player.play()

func stop_all():
	music.stop()
	music.stream=null
	for voice in voices:
		voice.stop()
		voice.stream=null

func _exit_tree():
	stop_all()
