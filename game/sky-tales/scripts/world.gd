extends Node3D

const Rules=preload("res://scripts/rules.gd")
const Art=preload("res://scripts/models.gd")
const Land=preload("res://scripts/terrain.gd")
const Clay=preload("res://scripts/sculpt.gd")
var art=Art.new()
var islands: Array[Node3D]=[]
var outlines: Array[PackedVector2Array]=[]
var resources: Array[Dictionary]=[]
var stations: Array[Dictionary]=[]
var crops: Array[Dictionary]=[]
var gates: Array[Dictionary]=[]
var bridges: Array[Dictionary]=[]
var blocks: Array[Dictionary]=[]
var waters: Array[Dictionary]=[]
var owned: Array=[0]
var batches: Dictionary={}
var clouds: Array[Dictionary]=[]
var wisps: Array[Dictionary]=[]
var random:=RandomNumberGenerator.new()
var elapsed:=0.0
var chest_opened:=false

func generate():
	lighting()
	for id in Rules.ISLES.size():
		var data=Rules.ISLES[id]
		var root:=Node3D.new()
		root.name="Isle%d"%id
		add_child(root)
		root.position=Vector3(data[1],0,data[2])
		islands.append(root)
		var poly=Land.footprint(data[3],data[4],id)
		outlines.append(poly)
		instance(root,Land.ground_mesh(poly,id))
	for link in Rules.LINKS:
		make_link(link[0],link[1])
	for id in islands.size():
		random.seed=4019+id*273
		populate(id)
		bake_decor(id)
	sky_floor()
	create_clouds()
	set_owned([0])

func lighting():
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#a9dbf4")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#f4f1fc")
	env.ambient_light_energy=.60
	env.ambient_light_sky_contribution=0
	env.ssao_enabled=true
	env.ssao_radius=.93
	env.ssao_intensity=1.6
	env.fog_enabled=true
	env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_light_color=Color("#d9ddf0")
	env.fog_depth_begin=62
	env.fog_depth_end=119
	env.fog_density=.34
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	var atmosphere:=WorldEnvironment.new()
	atmosphere.environment=env
	add_child(atmosphere)
	var sun:=DirectionalLight3D.new()
	add_child(sun)
	sun.position=Vector3(-15,29,-13)
	sun.look_at(Vector3.ZERO)
	sun.light_color=Color("#fff0d4")
	sun.light_energy=.92
	sun.light_angular_distance=.65
	sun.shadow_enabled=true
	sun.shadow_opacity=.69
	sun.shadow_bias=.035
	sun.directional_shadow_max_distance=110
	sun.directional_shadow_blend_splits=true

func center(id: int) -> Vector2:
	return Vector2(Rules.ISLES[id][1],Rules.ISLES[id][2])

func instance(parent: Node3D, mesh: Mesh, pos:=Vector3.ZERO) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	parent.add_child(node)
	node.position=pos
	return node

func model(id: int, kind: String, p: Vector2, size:=1.0, yaw:=0.0) -> MeshInstance3D:
	var m=instance(islands[id],art.get_mesh(kind),Vector3(p.x,0,p.y))
	m.scale=Vector3.ONE*size
	m.rotation.y=yaw
	return m

func decor(id: int, kind: String, p: Vector2, size:=1.0, yaw:=0.0):
	if not batches.has(kind):
		batches[kind]=[]
	batches[kind].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),Vector3(p.x,0,p.y)))
	var dimensions={"crate":Vector2(.41,.41),"barrel":Vector2(.30,.30),"logs":Vector2(.62,.82),
		"stump":Vector2(.37,.37),"fence":Vector2(1.11,.13),"cart":Vector2(.53,.61),
		"pillar":Vector2(.38,.38),"cave":Vector2(1.12,.70),"scarecrow":Vector2(.11,.11)}
	if dimensions.has(kind):
		blocks.append({"isle":id,"p":center(id)+p,"half":dimensions[kind]*size,"yaw":yaw})
	if kind=="arch":
		for x in [-.91,.91]:
			blocks.append({"isle":id,"p":center(id)+p+Vector2(x,0)*size,"half":Vector2(.32,.32)*size,"yaw":yaw})

func blocked(id,p,pad):
	for item in blocks:
		if item.isle!=id:
			continue
		var delta=(p-item.p).rotated(item.yaw).abs()
		if delta.x<item.half.x+pad.x and delta.y<item.half.y+pad.y:
			return true
	return false

func bake_decor(id: int):
	for kind in batches:
		var transforms=batches[kind]
		var mesh:=MultiMesh.new()
		mesh.transform_format=MultiMesh.TRANSFORM_3D
		mesh.mesh=art.get_mesh(kind)
		mesh.instance_count=transforms.size()
		for i in transforms.size():
			mesh.set_instance_transform(i,transforms[i])
		var node:=MultiMeshInstance3D.new()
		node.multimesh=mesh
		islands[id].add_child(node)
		if kind in ["grass","yellow","flowers","pebbles","fern"]:
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batches.clear()

func make_resource(id: int, kind: String, p: Vector2, size:=1.0):
	var visual=kind
	if kind=="tree":
		visual="tree%d"%random.randi_range(0,4)
	var node=model(id,visual,p,size,random.randf()*TAU)
	resources.append({"id":resources.size(),"isle":id,"kind":kind,"p":center(id)+p,"node":node,
		"hp":float(Rules.RESOURCES[kind][1]),"rest":0.0,"size":size,"yaw":node.rotation.y})

func station(id: int, kind: String, p: Vector2, built:=false) -> Dictionary:
	var m=model(id,kind,p,1.32 if kind=="house" else 1.0)
	var st={"id":stations.size(),"isle":id,"kind":kind,"p":center(id)+p,"node":m,"built":built,"queue":[],"work":0.0}
	stations.append(st)
	if kind in ["house","furnace"]:
		chimney(id,m,kind)
	return st

func chimney(id,parent,kind):
	var source=Vector3(.64,3.20,-.71) if kind=="house" else Vector3(0,1.60,0)
	var puff:=SphereMesh.new()
	puff.radius=.19
	puff.height=.35
	puff.radial_segments=8
	puff.rings=4
	var mat:=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(.86,.86,.84,.4)
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material=mat
	for i in 3:
		var node=instance(parent,puff,source)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisps.append({"node":node,"origin":source,"phase":i/3.0,"isle":id})

func home():
	station(0,"house",Vector2(2.15,-5.35))
	station(0,"furnace",Vector2(-2.80,-3.30))
	station(0,"bench",Vector2(-5.52,-1.94))
	for row in [["barrel",4.74,-4.8,1.12],["crate",6.62,-4.5,1.15],["crate",.18,-5.74,1.05],
			["crate",-.30,-5.17,.85],["logs",-6.43,1.87,1.05],["stump",-3.94,-.26,1.16],
			["fence",-5.1,-5.10,1.34],["fence",-7.99,-5.10,1.30]]:
		decor(0,row[0],Vector2(row[1],row[2]),row[3])
	for p in [Vector2(-8,-.72),Vector2(-8.27,3.20),Vector2(-6.68,-2.90),Vector2(7.2,.49),
			Vector2(5.94,5.77),Vector2(4.63,6.04),Vector2(3.32,5.93),Vector2(-1.1,7.02),
			Vector2(6.55,-6.7)]: make_resource(0,"tree",p,random.randf_range(.84,1.07))
	for p in [Vector2(1.63,1.8),Vector2(3.25,.30),Vector2(-1.0,3.8),Vector2(-6.10,.04),
			Vector2(-7.12,-1.34),Vector2(-3.04,4.7),Vector2(.20,-2.92),Vector2(6.84,2.70)]:
		make_resource(0,"stone",p,random.randf_range(1.00,1.35))
	for p in [Vector2(-4.79,2.38),Vector2(2,4.65),Vector2(6.68,-6.05),Vector2(4.84,-7.2)]:
		make_resource(0,"berrybush",p)
	for i in 6:
		decor(0,"pebbles",Vector2(2.16+sin(i*.9)*.42,-3.72+i*.24),1.5)

func populate(id: int):
	if id==0:
		home()
	if id==1:
		decor(id,"cart",Vector2(.2,-.36),1.05,.25)
		decor(id,"barrel",Vector2(-3.95,-3.1))
		decor(id,"crate",Vector2(-5,-2.7))
		decor(id,"logs",Vector2(3.72,-3.4),.91)
	if id==2:
		decor(id,"cave",Vector2(.45,-5.23),1.25)
		decor(id,"bench",Vector2(-3.8,-2.55))
		decor(id,"cart",Vector2(2.7,-4.8),.77)
	if id in [3,7,9]:
		pond(id,Vector2(-.64,.16),Vector2(3.9,3.04),id==7)
	if id==6:
		decor(id,"arch",Vector2(0,-4.24),1.05)
		for x in [-4.45,-2.18,2.18,4.45]:
			for z in [-3.5,3.36]:
				decor(id,"pillar",Vector2(x,z),random.randf_range(.82,1.13),random.randf_range(-.13,.13))
		var s=Clay.new()
		for x in range(-3,4):
			for z in range(-3,4):
				if abs(x)+abs(z)>4:
					continue
				s.box(Vector3(x*.63,.024,z*.59),Vector3(.604,.055,.567),Color("#d9ceb9").darkened(random.randf_range(0,.06)))
		instance(islands[id],s.mesh())
		station(id,"chest",Vector2.ZERO)
	if id==10:
		farm(id)
	if id>0:
		scatter_resources(id)
	var total=int(Rules.ISLES[id][3]*Rules.ISLES[id][4]*.46)
	for i in total:
		var p=random_site(id,.35)
		if not available(id,p,.22):
			continue
		var k=["grass","grass","grass","fern","flowers","yellow","pebbles","mushrooms","grass","fern","flowers","grass","grass","fern","yellow","grass","grass","pebbles","grass"]
		var kind=k[random.randi_range(0,k.size()-1)]
		if id==5 and i%2==0:
			kind="flowers"
		decor(id,kind,p,random.randf_range(.69,1.18),random.randf()*TAU)

func random_site(id,margin) -> Vector2:
	var w=float(Rules.ISLES[id][3])
	var h=float(Rules.ISLES[id][4])
	for attempt in 40:
		var p=Vector2(random.randf_range(-w*.5+margin,w*.5-margin),random.randf_range(-h*.5+margin,h*.5-margin))
		if in_isle(id,center(id)+p,margin):
			return p
	return Vector2.ZERO

func scatter_resources(id):
	var types: Array
	match id:
		1: types=["iron_ore","iron_ore","iron_ore","stone","stone","iron_ore","tree"]
		2: types=["crystal","crystal","crystal","iron_ore","stone","tree","iron_ore"]
		4: types=["gold_ore","gold_ore","iron_ore","stone","gold_ore","tree"]
		6: types=["stone","tree","gold_ore"]
		_: types=["tree","tree","berrybush","tree","stone","berrybush"]
	var target=18 if id in [1,2,4,9] else (8 if id in [6,8,10] else 13)
	var placed:=0
	for attempt in 180:
		if placed>=target:
			break
		var p=random_site(id,.62)
		if not available(id,p,1.08):
			continue
		if id==6 and absf(p.x)<4.9 and absf(p.y)<4.1:
			continue
		if id==10 and absf(p.y)<3.3:
			continue
		if id==1 and p.length()<1.55:
			continue
		if id==2 and p.distance_to(Vector2(.45,-5.23))<1.6:
			continue
		make_resource(id,types[placed%types.size()],p,random.randf_range(.85,1.19))
		placed+=1

func pond(id,p,size,falling):
	var z_end=size.y*.5
	if falling:
		z_end=edge(id,center(id).x,true,true)-center(id).y-p.y+.12
	var contour=PackedVector2Array([Vector2(-.5*size.x,-.5*size.y),Vector2(.5*size.x,-.5*size.y),
		Vector2(.5*size.x,z_end),Vector2(-.08*size.x,z_end),Vector2(-.08*size.x,.32*size.y),Vector2(-.53*size.x,.30*size.y)])
	if not falling:
		contour=PackedVector2Array([Vector2(-.52*size.x,-.44*size.y),Vector2(.48*size.x,-.48*size.y),Vector2(.52*size.x,.46*size.y),Vector2(-.45*size.x,.46*size.y)])
	contour=Land.round_poly(contour,.42)
	var rim_poly=PackedVector2Array()
	for v in contour:
		rim_poly.append(v*1.052)
	var rim=StandardMaterial3D.new()
	rim.albedo_color=Color("#e8dbac")
	instance(islands[id],Land.flat(rim_poly,.034,rim),Vector3(p.x,0,p.y))
	instance(islands[id],Land.flat(contour,.045,Land.water()),Vector3(p.x,0,p.y))
	waters.append({"isle":id,"p":center(id)+p,"poly":contour})
	for off in [Vector2(-.80,-.72),Vector2(.91,.67)]:
		var lil=model(id,"pad",p+off)
		lil.position.y=.055
	if falling:
		var quad:=QuadMesh.new()
		quad.size=Vector2(size.x*.58,5.15)
		var shader:=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_disabled;
		void fragment(){float edge=smoothstep(0.,.11,UV.x)*smoothstep(0.,.11,1.-UV.x);
		float stripe=.5+.5*sin(UV.x*76.+sin(UV.y*8.-TIME*3.));
		ALBEDO=mix(vec3(.42,.77,.92),vec3(.89,.97,1.),stripe*.67);ALPHA=(.48+.40*stripe)*edge*(1.-smoothstep(.65,1.,UV.y));}"""
		var mat:=ShaderMaterial.new()
		mat.shader=shader
		quad.material=mat
		var sheet=instance(islands[id],quad,Vector3(p.x+size.x*.21,-2.49,p.y+z_end))
		sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func farm(id):
	pond(id,Vector2(6.15,.18),Vector2(2.75,2.62),false)
	for row in [[-5.6,"carrot",3],[-1.67,"cabbage",2],[2.08,"turnip",3]]:
		for iz in row[2]:
			for ix in 2:
				var p=Vector2(row[0]+ix*1.25,(iz-1)*1.25)
				model(id,"crop_soil",p)
				var node=model(id,row[1],p)
				var age=Rules.GROW_TIME[row[1]]*(.24+.33*iz)
				crops.append({"p":center(id)+p,"isle":id,"kind":row[1],"age":age,"initial_kind":row[1],"initial_age":age,"planted":false,"node":node})
	for x in [-5.2,2.85]:
		decor(id,"fence",Vector2(x,-3.55),1.32)
	decor(id,"barrel",Vector2(7.37,2.19))
	decor(id,"scarecrow",Vector2(-3.01,2.09))
	decor(id,"crate",Vector2(6.38,-3.25))

func in_isle(id: int, p: Vector2, margin:=0.0) -> bool:
	var q=p-center(id)
	if absf(q.x)>float(Rules.ISLES[id][3])*.5+.15 or absf(q.y)>float(Rules.ISLES[id][4])*.5+.15:
		return false
	if not Geometry2D.is_point_in_polygon(q,outlines[id]):
		return false
	if margin>0:
		for v in [Vector2(margin,0),Vector2(-margin,0),Vector2(0,margin),Vector2(0,-margin)]:
			if not Geometry2D.is_point_in_polygon(q+v,outlines[id]):
				return false
	return true

func wet(id,p):
	for w in waters:
		if w.isle==id and Geometry2D.is_point_in_polygon(p-w.p,w.poly):
			return true
	return false

func available(id,p,margin):
	var wp=center(id)+p
	if wet(id,wp) or blocked(id,wp,Vector2.ONE*margin):
		return false
	for s in stations:
		if s.isle==id and s.p.distance_to(wp)<margin+(1.72 if s.kind=="house" else .92):
			return false
	for r in resources:
		if r.isle==id and r.p.distance_to(wp)<margin+.72:
			return false
	for g in gates:
		if g.isle==id and g.p.distance_to(wp)<margin+1.0:
			return false
	for c in crops:
		if c.isle==id and c.p.distance_to(wp)<margin+.67:
			return false
	return true

func edge(id,perp,vertical,positive) -> float:
	var line=perp-(center(id).x if vertical else center(id).y)
	var hits: Array[float]=[]
	var poly=outlines[id]
	for i in poly.size():
		var a=poly[i]
		var b=poly[(i+1)%poly.size()]
		var v0=a.x if vertical else a.y
		var v1=b.x if vertical else b.y
		if absf(v1-v0)<.00001 or line<minf(v0,v1) or line>maxf(v0,v1):
			continue
		var ip=a.lerp(b,(line-v0)/(v1-v0))
		hits.append(ip.y if vertical else ip.x)
	if hits.is_empty():
		return center(id).y if vertical else center(id).x
	return (hits.max() if positive else hits.min())+(center(id).y if vertical else center(id).x)

func make_link(a,b):
	var ca=center(a)
	var cb=center(b)
	var diff=cb-ca
	var vertical=absf(diff.y)>absf(diff.x)
	var positive=diff.y>0 if vertical else diff.x>0
	var perp=(ca.x+cb.x)*.5 if vertical else (ca.y+cb.y)*.5
	var half_a=float(Rules.ISLES[a][3 if vertical else 4])*.5
	var half_b=float(Rules.ISLES[b][3 if vertical else 4])*.5
	var axis_a=ca.x if vertical else ca.y
	var axis_b=cb.x if vertical else cb.y
	var lo=maxf(axis_a-half_a*.77,axis_b-half_b*.77)
	var hi=minf(axis_a+half_a*.77,axis_b+half_b*.77)
	if lo<=hi:
		perp=clampf(perp,lo,hi)
	var ea=edge(a,perp,vertical,positive)
	var eb=edge(b,perp,vertical,not positive)
	var pa=Vector2(perp,ea) if vertical else Vector2(ea,perp)
	var pb=Vector2(perp,eb) if vertical else Vector2(eb,perp)
	var dir=pa.direction_to(pb)
	var ends=[[a,b,pa-dir*.78],[b,a,pb+dir*.78]]
	for end in ends:
		var m=model(end[0],"sign",end[2]-center(end[0]),.98)
		gates.append({"isle":end[0],"target":end[1],"p":end[2],"node":m})
	var root:=Node3D.new()
	add_child(root)
	root.position=Vector3(pa.x,0,pa.y)
	root.rotation.y=atan2(dir.x,dir.y)
	var length=pa.distance_to(pb)
	var count=maxi(4,ceili(length/.63))
	for j in count:
		var s=Clay.new()
		var step=length/count
		for x in [-.52,.52]:
			s.box(Vector3(x,-.115,0),Vector3(.15,.21,step+.035),Color("#956b49"))
		s.box(Vector3(0,.005,0),Vector3(1.56,.14,step-.025),Color("#d2a36c").lightened((j%3)*.026))
		for x in [-.74,.74]:
			s.box(Vector3(x,.245,0),Vector3(.075,.072,step+.012),Color("#c6a475"))
			if j%3==0 or j==count-1:
				s.rod(Vector3(x,-.34,0),Vector3(x,.43,0),.085,Color("#b58655"))
		instance(root,s.mesh(),Vector3(0,0,(j+.5)*step))
	bridges.append({"a":a,"b":b,"p":pa,"q":pb,"root":root})

func set_owned(ids: Array, unlock: int=-1):
	owned=ids.duplicate()
	for i in islands.size():
		if i==unlock:
			var tween=create_tween()
			tween.tween_property(islands[i],"position:y",0.0,.86).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			islands[i].position.y=0.0 if i in owned else -.96
	for b in bridges:
		var on=b.a in owned and b.b in owned
		var animate_bridge=on and not b.root.visible and unlock>=0
		b.root.visible=on
		if animate_bridge:
			for j in b.root.get_child_count():
				var board=b.root.get_child(j)
				var tween=create_tween()
				board.position.y=-1.15
				var order=j if b.b==unlock else b.root.get_child_count()-1-j
				tween.tween_interval(order*.045)
				tween.tween_property(board,"position:y",0.0,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for g in gates:
		g.node.visible=g.isle in owned and g.target not in owned

func land_at(p: Vector2) -> int:
	for i in owned:
		if in_isle(i,p):
			return i
	return -1

func walkable(p: Vector2) -> bool:
	for b in bridges:
		if not b.root.visible:
			continue
		var dir:Vector2=b.p.direction_to(b.q)
		if Geometry2D.get_closest_point_to_segment(p,b.p-dir*.38,b.q+dir*.38).distance_to(p)<.59:
			return true
	var id=land_at(p)
	if id<0 or not in_isle(id,p,.17) or wet(id,p) or blocked(id,p,Vector2(.14,.14)):
		return false
	for s in stations:
		if s.isle!=id:
			continue
		var delta=(p-s.p).abs()
		if s.kind=="house" and delta.x<1.82 and delta.y<1.45:
			return false
		if s.kind=="market" and delta.x<1.20 and delta.y<.82:
			return false
		if s.kind not in ["house","market"] and delta.length()<.62:
			return false
	for r in resources:
		if r.isle==id and r.rest<=0 and r.p.distance_squared_to(p)<.15*r.size*r.size:
			return false
	return true

func can_build(p: Vector2) -> bool:
	var id=land_at(p)
	if id<0 or blocked(id,p,Vector2(1.18,.86)):
		return false
	for corner in [Vector2(-1.20,-.89),Vector2(1.20,-.89),Vector2(-1.20,.89),Vector2(1.20,.89),Vector2.ZERO]:
		if not in_isle(id,p+corner,.17) or wet(id,p+corner):
			return false
	for s in stations:
		var delta=(p-s.p).abs()
		if s.isle==id and delta.x<(3.0 if s.kind=="house" else 2.25) and delta.y<(2.30 if s.kind=="house" else 1.75):
			return false
	for r in resources:
		if r.isle==id and r.rest<=0 and (p-r.p).abs().x<1.42 and (p-r.p).abs().y<1.13:
			return false
	for g in gates:
		if g.isle==id and g.p.distance_to(p)<1.65:
			return false
	for c in crops:
		if c.isle==id and c.p.distance_to(p)<1.65:
			return false
	return true

func create_clouds():
	random.seed=62918
	var textures=[preload("res://art/cloud0.png"),preload("res://art/cloud1.png"),preload("res://art/cloud2.png")]
	var quads=[]
	for texture in textures:
		var mat:=StandardMaterial3D.new()
		mat.albedo_texture=texture
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale=true
		mat.disable_receive_shadows=true
		mat.vertex_color_use_as_albedo=false
		var q:=QuadMesh.new()
		q.size=Vector2(1,.555)
		q.material=mat
		quads.append(q)
	for row in range(-5,5):
		for col in range(-6,7):
			if random.randf()<.27:
				continue
			var p=Vector3(col*11.5+random.randf_range(-4,4),random.randf_range(-10.9,-5.1),row*10.5+random.randf_range(-3,3))
			var node=instance(self,quads[random.randi_range(0,2)],p)
			var width=random.randf_range(10.4,23.5)
			node.scale=Vector3(width,width*random.randf_range(.77,1.32),width)
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clouds.append({"node":node,"p":p,"phase":random.randf()*TAU})

func sky_floor():
	var plane:=PlaneMesh.new()
	plane.size=Vector2(260,240)
	var shader:=Shader.new()
	shader.code="""shader_type spatial;render_mode unshaded,fog_disabled;
	varying vec2 pos;
	void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
	float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
	float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
	float cloud(vec2 p){return .50*noise2(p)+.29*noise2(p*2.09+16.)+.14*noise2(p*4.1-3.)+.07*noise2(p*8.2);}
	void fragment(){
	vec2 p=pos*.067+vec2(TIME*.0018,0);float n=cloud(p);
	float farbank=smoothstep(.47,.73,n);float light=smoothstep(-.11,.10,cloud(p-vec2(.1,.12))-n);
	vec3 sky=mix(vec3(.30,.60,.85),vec3(.60,.81,.91),clamp(.66-pos.y*.010+.18*noise2(p*.6),0.,1.));
	vec3 mist=mix(vec3(.65,.70,.84),vec3(.94,.95,.97),light);
	ALBEDO=mix(sky,mist,farbank*.88);}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	plane.material=mat
	var background=instance(self,plane,Vector3(0,-19,0))
	background.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var distant=StandardMaterial3D.new()
	distant.albedo_color=Color("#a8cdd1")
	distant.roughness=1.
	distant.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for q in [Vector3(-43,-9,-29),Vector3(-25,-12,-46),Vector3(14,-13,-46),Vector3(52,-10,-29),Vector3(62,-9,3),Vector3(-49,-12,15)]:
		var land=instance(self,Land.ground_mesh(Land.footprint(7,5,3),3),q)
		land.material_override=distant
		for j in 4:
			var tree=instance(self,art.get_mesh("tree2"),q+Vector3(sin(j*2.3)*2.1,0,cos(j*3.1)*1.5))
			tree.scale=Vector3.ONE*.62
			tree.material_override=distant

func on_bridge(p:Vector2) -> bool:
	for b in bridges:
		if b.root.visible and Geometry2D.get_closest_point_to_segment(p,b.p,b.q).distance_to(p)<.76:
			return true
	return false

func fade_canopies(p:Vector2,dt):
	for r in resources:
		if r.kind!="tree":
			continue
		var delta=(p-r.p-Vector2(0,-1.05*r.size))/Vector2(1.13*r.size,.97*r.size)
		var amount=.61 if r.rest<=0 and delta.length_squared()<1. and r.isle in owned else 0.
		if absf(r.node.transparency-amount)>.005:
			r.node.transparency=lerpf(r.node.transparency,amount,1-exp(-dt*12))

func animate(dt):
	elapsed+=dt
	for c in clouds:
		c.node.position.x=c.p.x+sin(elapsed*.044+c.phase)*1.75
	for i in range(wisps.size()-1,-1,-1):
		var w=wisps[i]
		if not is_instance_valid(w.node):
			wisps.remove_at(i)
			continue
		var t=fmod(elapsed*.50+w.phase,1.)
		w.node.position=w.origin+Vector3(t*.44,t*1.24,sin(t*4)*.08)
		w.node.scale=Vector3.ONE*(.32+sin(t*PI)*.71)
		w.node.visible=t<.94

func set_chest(opened):
	chest_opened=opened
	for s in stations:
		if s.kind=="chest":
			s.node.mesh=art.get_mesh("chest_open" if opened else "chest")
