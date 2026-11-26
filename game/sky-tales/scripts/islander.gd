extends Node3D

const Clay=preload("res://scripts/sculpt.gd")
var body:=Node3D.new()
var legs: Array[Node3D]=[]
var arms: Array[Node3D]=[]
var tool:=Node3D.new()
var stride:=0.0
var swing:=0.0
var heading:=0.0
var tier:=-1

func part(parent,sculpt):
	var node:=MeshInstance3D.new()
	node.mesh=sculpt.mesh()
	parent.add_child(node)
	return node

func assemble():
	add_child(body)
	var s=Clay.new()
	s.blob(Vector3(0,.55,0),Vector3(.49,.47,.31),Color("#83b2c1"))
	s.blob(Vector3(0,.44,.087),Vector3(.43,.35,.25),Color("#917557"))
	s.box(Vector3(-.121,.61,.132),Vector3(.058,.26,.036),Color("#a18760"),Vector3(0,0,-.12))
	s.box(Vector3(.121,.61,.132),Vector3(.058,.26,.036),Color("#a18760"),Vector3(0,0,.12))
	s.blob(Vector3(-.12,.64,.155),Vector3.ONE*.047,Color("#d9b65c"))
	s.blob(Vector3(.12,.64,.155),Vector3.ONE*.047,Color("#d9b65c"))
	s.blob(Vector3(0,.93,0),Vector3(.54,.53,.47),Color("#e5b78f"))
	s.blob(Vector3(0,1.022,-.04),Vector3(.56,.44,.47),Color("#624736"))
	s.blob(Vector3(.04,.97,.198),Vector3(.44,.34,.126),Color("#edc49b"))
	for x in [-.115,.115]:
		s.blob(Vector3(x,.974,.260),Vector3(.052,.064,.025),Color("#433830"))
		s.blob(Vector3(x-.010,.99,.273),Vector3(.014,.015,.008),Color("#fff2ce"))
		s.blob(Vector3(x*1.42,.911,.244),Vector3(.069,.031,.022),Color("#d99882"))
	s.blob(Vector3(.01,.932,.273),Vector3(.061,.046,.041),Color("#daa880"))
	for i in 3:
		s.blob(Vector3(-.15+i*.10,1.101-(i%2)*.027,.183),Vector3(.17,.15,.12),Color("#745039"))
	s.blob(Vector3(0,1.195,-.07),Vector3(.85,.083,.70),Color("#e6c487"),Vector3(-.085,0,.035))
	s.blob(Vector3(-.03,1.31,-.066),Vector3(.62,.36,.56),Color("#edce99"))
	s.rod(Vector3(-.027,1.212,-.017),Vector3(-.027,1.264,-.017),.315,Color("#aa8053"),.977,16)
	s.blob(Vector3(0,.57,-.19),Vector3(.31,.32,.20),Color("#bc9861"))
	part(body,s)
	for sign_value in [-1,1]:
		var leg:=Node3D.new()
		leg.position=Vector3(.115*sign_value,.385,0)
		body.add_child(leg)
		var l=Clay.new()
		l.blob(Vector3(0,-.12,0),Vector3(.192,.33,.203),Color("#7f765e"))
		l.blob(Vector3(0,-.298,.039),Vector3(.207,.16,.278),Color("#594936"))
		part(leg,l)
		legs.append(leg)
		var arm:=Node3D.new()
		arm.position=Vector3(.261*sign_value,.723,0)
		body.add_child(arm)
		var a=Clay.new()
		a.blob(Vector3(0,-.075,0),Vector3(.166,.219,.178),Color("#9ec5c9"))
		a.blob(Vector3(0,-.216,.028),Vector3(.133,.171,.144),Color("#e8bc90"))
		part(arm,a)
		arms.append(arm)
	arms[0].add_child(tool)
	tool.position=Vector3(-.015,-.224,.042)
	set_tool(0)

func set_tool(value):
	if tier==value:
		return
	tier=value
	for n in tool.get_children():
		tool.remove_child(n)
		n.queue_free()
	var s=Clay.new()
	s.rod(Vector3(0,-.075,-.14),Vector3(0,.25,.38),.031,Color("#996e49"),.89,7)
	var col=Color(["#a8a6a3","#a9bbcb","#edbf54"][clampi(value,0,2)])
	s.rod(Vector3(0,.25,.38),Vector3(-.18,.209,.40),.057,col,.57,6)
	s.rod(Vector3(-.18,.209,.40),Vector3(-.26,.128,.42),.033,col,.02,6)
	s.rod(Vector3(0,.25,.38),Vector3(.17,.23,.37),.059,col,.64,6)
	s.rod(Vector3(.17,.23,.37),Vector3(.245,.15,.38),.036,col,.03,6)
	part(tool,s)

func face(dir:Vector2):
	if dir.length_squared()>.0002:
		heading=atan2(dir.x,dir.y)

func tick(dt:float,moving:bool):
	stride+=dt*(12.7 if moving else 2.5)
	rotation.y=lerp_angle(rotation.y,heading,1-exp(-dt*16))
	var pace=sin(stride) if moving else 0.0
	body.position.y=absf(pace)*.072+sin(stride)*(.012 if not moving else 0.0)
	legs[0].rotation.x=pace*.52
	legs[1].rotation.x=-pace*.52
	arms[1].rotation.x=pace*.39
	swing=maxf(0,swing-dt*3.8)
	var strike=sin((1.-swing)*PI) if swing>0 else 0.0
	arms[0].rotation.x=-pace*.38-strike*1.85
	body.rotation.z=sin(stride)*(.026 if moving else .008)+strike*.075
