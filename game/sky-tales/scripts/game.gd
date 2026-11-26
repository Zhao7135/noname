extends Node3D

const R=preload("res://scripts/rules.gd")
const Islands=preload("res://scripts/world.gd")
const Islander=preload("res://scripts/islander.gd")
const Interface=preload("res://scripts/interface.gd")
const Audio=preload("res://scripts/sounds.gd")
const Clay=preload("res://scripts/sculpt.gd")
const SAVE="user://archipelago.json"
var world=Islands.new()
var avatar=Islander.new()
var ui=Interface.new()
var sounds=Audio.new()
var camera:=Camera3D.new()
var p:=Vector2(0,.85)
var cam_focus:=Vector3(5,0,4)
var zoom:=15.1
var started:=false
var closing:=false
var money:=0
var level:=1
var xp:=0
var energy:=100.0
var tool_tier:=0
var goal:=0
var bag:Dictionary={}
var skills:Dictionary={}
var totals:Dictionary={}
var skill_choices:Array=[]
var pending:=0
var harvesting:=false
var cooldown:=0.0
var step_time:=0.0
var ambience_time:=2.0
var dirty:=false
var save_timer:=0.0
var hud_timer:=0.0
var placing:=""
var ghost:MeshInstance3D
var grid:MeshInstance3D
var grid_isle:=-1
var placement:=Vector2.ZERO
var active_station:Dictionary={}
var active_plot:Dictionary={}
var focus:Dictionary={}
var near:Dictionary={}
var pickups:Array[Dictionary]=[]
var debris:Array[Dictionary]=[]
var drop_models:Dictionary={}
var rng:=RandomNumberGenerator.new()
var display_market:MeshInstance3D
var save_snapshot:Dictionary={}

func _ready():
	get_tree().auto_accept_quit=false
	rng.randomize()
	add_child(world)
	world.generate()
	add_child(avatar)
	avatar.assemble()
	avatar.scale=Vector3.ONE*1.17
	avatar.position=Vector3(p.x,0,p.y)
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=61
	camera.far=230
	camera.current=true
	camera.look_at_from_position(cam_focus+Vector3(0,46,32),cam_focus)
	add_child(sounds)
	sounds.prepare()
	add_child(ui)
	ui.setup(self)
	display_market=world.model(0,"market",Vector2(2.0,2.1))
	open_title()

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		close_game()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		harvesting=false

func close_game():
	if closing:
		return
	closing=true
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if started:
		save_game()
	sounds.stop_all()
	await get_tree().create_timer(.24,true,false,true).timeout
	get_tree().quit()

func open_title():
	started=false
	harvesting=false
	avatar.visible=false
	display_market.visible=true
	world.set_owned(range(R.ISLES.size()))
	ui.overlay.hide()
	save_snapshot=read_save()
	if not save_snapshot.is_empty():
		sounds.set_levels(save_snapshot.get("music",.56),save_snapshot.get("fx",.78))
	ui.show_title(not save_snapshot.is_empty())

func start_game(resume:bool):
	if not resume and not save_snapshot.is_empty() and FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE),ProjectSettings.globalize_path("user://previous_archipelago.json"))
	reset_session()
	if resume and not save_snapshot.is_empty():
		restore(save_snapshot)
	started=true
	display_market.visible=false
	avatar.visible=true
	avatar.set_tool(tool_tier)
	avatar.position=Vector3(p.x,0,p.y)
	avatar.rotation.y=avatar.heading
	ui.close()
	ui.hud.show()
	ui.overlay.show()
	ui.update_hud()
	ui.notice("已回到家园" if resume else "WASD 移动，靠近树或岩石后按住左键")
	sounds.play("ready",.62)
	dirty=true
	offer_level()

func reset_session():
	money=0
	level=1
	xp=0
	energy=100.
	goal=0
	tool_tier=0
	bag={}
	skills={}
	totals={}
	pending=0
	skill_choices=[]
	p=Vector2(0,.85)
	zoom=15.1
	near={}
	focus={}
	active_station={}
	active_plot={}
	cooldown=0
	step_time=0
	cancel_build()
	for item in pickups:
		item.node.queue_free()
	pickups.clear()
	for i in range(world.stations.size()-1,-1,-1):
		var s=world.stations[i]
		if s.built:
			s.node.queue_free()
			world.stations.remove_at(i)
		else:
			s.queue=[]
			s.work=0.0
	for r in world.resources:
		r.hp=float(R.RESOURCES[r.kind][1])
		r.rest=0.
		r.node.show()
		r.node.rotation.z=0.
		r.node.scale=Vector3.ONE*r.size
	for c in world.crops:
		c.kind=c.get("initial_kind",c.kind)
		c.age=c.get("initial_age",c.age)
		c.planted=false
		update_crop(c)
	world.set_owned([0])
	world.set_chest(false)

func to_title():
	if not save_game():
		ui.notice("存档写入失败，请检查磁盘后重试")
		return
	open_title()

func count(k):
	return int(bag.get(k,0))
func put(k,n):
	bag[k]=maxi(0,count(k)+int(n))
	if bag[k]==0:
		bag.erase(k)
	dirty=true
func track(k,n=1):
	totals[k]=int(totals.get(k,0))+n
	dirty=true
func stat(k):
	return int(totals.get(k,0))
func next_xp():
	return 15+(level-1)*12
func max_energy():
	return 100+int(skills.get("energy",0))*25
func strength():
	return (1.0+tool_tier*.72)*(1.+int(skills.get("power",0))*.25)
func island_price():
	return 25+20*(world.owned.size()-1)
func recipe_time(key):
	return float(R.RECIPES[key].time)/(1.+.30*int(skills.get("craft",0)))
func upgrade_cost():
	return {"iron":3,"wood":6} if tool_tier==0 else {"gold":3,"crystal":4}

func affords(cost:Dictionary,qty:=1) -> bool:
	for k in cost:
		if count(k)<cost[k]*qty:
			return false
	return true
func pay(cost:Dictionary,qty:=1):
	for k in cost:
		put(k,-cost[k]*qty)
func cost_text(cost:Dictionary,with_stock:=false) -> String:
	var parts:PackedStringArray=[]
	for k in cost:
		parts.append(("%s %d/%d"%[R.NAMES[k],count(k),cost[k]]) if with_stock else ("%s %d"%[R.NAMES[k],cost[k]]))
	return "　".join(parts)

func add_xp(n):
	xp+=int(n)
	dirty=true
	while xp>=next_xp():
		xp-=next_xp()
		level+=1
		pending+=1
	offer_level()

func offer_level():
	if pending<=0 or not started or ui.menu!="" or placing!="":
		return
	if skill_choices.size()!=3:
		if level==2:
			skill_choices=["power","craft","magnet"]
		elif level==3:
			skill_choices=["magnet","energy","luck"]
		else:
			var deck=R.SKILLS.keys()
			for i in 3:
				skill_choices.append(deck.pop_at(rng.randi_range(0,deck.size()-1)))
	sounds.play("level",.85,0.)
	ui.level_menu()
	ui.update_hud()

func take_skill(k):
	if ui.menu!="level" or pending<=0 or k not in skill_choices:
		return
	skills[k]=int(skills.get(k,0))+1
	if k=="energy":
		energy=max_energy()
	pending-=1
	skill_choices=[]
	dirty=true
	ui.close()
	ui.notice("获得技能：%s　%s"%R.SKILLS[k])
	ui.update_hud()
	offer_level()

func _input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		harvesting=false
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var k=event.physical_keycode
	if not started:
		if ui.menu=="title" and k in [KEY_ENTER,KEY_SPACE]:
			start_game(not save_snapshot.is_empty())
		elif ui.menu=="confirm" and k==KEY_ESCAPE:
			ui.show_title(not save_snapshot.is_empty())
		else:
			return
	elif ui.menu!="":
		if k>=KEY_1 and k<=KEY_3 and k-KEY_1<ui.quicks.size():
			ui.quicks[k-KEY_1].call()
		elif k==KEY_ESCAPE or (k==KEY_E and ui.menu in ["furnace","market","forge","home","bench","seed"]) or (k==KEY_M and ui.menu=="map") or (k==KEY_H and ui.menu=="help") or (k==KEY_B and ui.menu=="build"):
			dismiss()
		else:
			return
	elif placing!="":
		if k==KEY_ESCAPE or k==KEY_B:
			cancel_build()
		else:
			return
	else:
		match k:
			KEY_E:interact()
			KEY_B:command("build")
			KEY_F:command("eat")
			KEY_H:command("help")
			KEY_M:command("map")
			KEY_ESCAPE:command("pause")
			_:return
	get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if not started or ui.menu!="" or event is not InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom=clampf(zoom-1.1,8.5,21)
			dirty=true
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom=clampf(zoom+1.1,8.5,21)
			dirty=true
		MOUSE_BUTTON_LEFT:
			if placing!="":
				update_placement()
				commit_build()
			else:
				harvesting=true
		MOUSE_BUTTON_RIGHT:
			if placing!="":
				cancel_build()

func command(key:String):
	if not started or ui.menu!="" or placing!="":
		return
	harvesting=false
	match key:
		"act":interact()
		"build":ui.build_menu()
		"eat":eat()
		"help":ui.help_menu()
		"map":ui.overview()
		"pause":ui.pause_menu();save_game()

func dismiss():
	if ui.menu=="level":
		return
	ui.close()
	active_station={}
	active_plot={}
	if started:
		ui.hud.show()
	else:
		open_title()
	offer_level()

func _process(dt):
	if not is_instance_valid(ui) or not is_instance_valid(ui.root) or not camera.is_inside_tree():
		return
	world.animate(dt)
	var wide=not started or ui.menu=="map"
	var aim=Vector3(5.4,0,4.3) if wide else Vector3(p.x,0,p.y-.64)
	var target_size=maxf(60.,82./maxf(1.,get_viewport().get_visible_rect().size.aspect())) if wide else zoom
	var blend=1-exp(-dt*(3.8 if wide else 6.4))
	cam_focus=cam_focus.lerp(aim,blend)
	camera.size=lerpf(camera.size,target_size,blend)
	camera.look_at_from_position(cam_focus+Vector3(0,46,32),cam_focus)
	if not started:
		return
	if ui.menu=="map":
		ui.map_positions()
	var step=minf(dt,.10)
	if ui.menu not in ["pause","help","level","map"]:
		process_queues(step)
		grow(step)
		update_pickups(step)
	var moving=false
	if ui.menu=="":
		var dir=Vector2(float(down(KEY_D,KEY_RIGHT))-float(down(KEY_A,KEY_LEFT)),float(down(KEY_S,KEY_DOWN))-float(down(KEY_W,KEY_UP))).normalized()
		if dir!=Vector2.ZERO:
			var old=p
			var change=dir*step*4.65
			for i in 2:
				var px=Vector2(p.x+change.x*.5,p.y)
				var py=Vector2(p.x,p.y+change.y*.5)
				if world.walkable(px):
					p.x=px.x
				py.x=p.x
				if world.walkable(py):
					p.y=py.y
			moving=old.distance_squared_to(p)>.000001
			avatar.face(dir)
			dirty=dirty or moving
		avatar.position=Vector3(p.x,0,p.y)
		world.fade_canopies(p,step)
		near=nearest_interaction()
		focus=nearest_resource()
		cooldown=maxf(0,cooldown-step)
		if harvesting and placing=="" and cooldown<=0:
			harvest()
		elif not harvesting:
			energy=minf(max_energy(),energy+step*.60)
		if placing!="":
			update_placement()
		step_time-=step
		if moving and step_time<=0:
			sounds.play("plank" if world.on_bridge(p) else "step",.22,.15)
			step_time=.31
		ambience_time-=step
		if ambience_time<=0:
			ambience_time=rng.randf_range(1.8,3.4)
			for water in world.waters:
				if water.isle in world.owned and water.p.distance_to(p)<5.4:
					sounds.play("water",.14,.18)
					break
			for st in world.stations:
				if not st.queue.is_empty() and st.p.distance_to(p)<4.1:
					sounds.play("fire",.11,.22)
					break
	else:
		harvesting=false
	avatar.tick(step,moving)
	animate_debris(step)
	ui.tick(step,near,focus)
	hud_timer+=dt
	if hud_timer>=.12:
		hud_timer=0
		ui.update_hud()
	save_timer+=dt
	if save_timer>=6.0:
		save_timer=0
		if dirty:
			save_game()

func down(a,b):
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func pointer_ground() -> Vector2:
	var mouse=get_viewport().get_mouse_position()
	var ray=camera.project_ray_normal(mouse)
	var origin=camera.project_ray_origin(mouse)
	var t=-origin.y/ray.y
	return Vector2(origin.x+ray.x*t,origin.z+ray.z*t)

func nearest_resource() -> Dictionary:
	var result:Dictionary={}
	var best:=INF
	var aim=pointer_ground()
	for r in world.resources:
		if r.isle not in world.owned or r.rest>0:
			continue
		var dist=p.distance_to(r.p)
		if dist>2.20:
			continue
		var score=dist*.77+minf(aim.distance_to(r.p),3.5)*.55
		if score<best:
			result=r
			best=score
	return result

func nearest_interaction() -> Dictionary:
	var result:Dictionary={}
	var best:=INF
	for s in world.stations:
		if s.isle not in world.owned:
			continue
		var d=p.distance_to(s.p)-(.95 if s.kind=="house" else (.55 if s.kind=="market" else .12))
		if d<1.85 and d<best:
			best=d
			result={"type":"station","obj":s}
	for g in world.gates:
		if g.isle not in world.owned or g.target in world.owned:
			continue
		var d=p.distance_to(g.p)
		if d<1.85 and d<best:
			best=d
			result={"type":"gate","obj":g}
	for c in world.crops:
		if c.isle not in world.owned:
			continue
		var d=p.distance_to(c.p)
		if d<1.29 and d<best:
			best=d
			result={"type":"plot","obj":c}
	return result

func context_name(entry):
	var o=entry.obj
	match entry.type:
		"gate":return "购买 %s（%d 金币）"%[R.ISLES[o.target][0],island_price()]
		"plot":
			if o.kind=="":
				return "在空地播种"
			if o.age>=R.GROW_TIME[o.kind]:
				return "收获"+R.NAMES[o.kind]
			return "%s生长中　%d 秒"%[R.NAMES[o.kind],ceili(R.GROW_TIME[o.kind]-o.age)]
		_:
			if o.kind=="house":
				return "回农舍休息"
			if o.kind=="chest":
				return "查看已开启的宝箱" if world.chest_opened else "打开遗迹宝箱"
			return "打开"+R.NAMES[o.kind]

func interact():
	if not started or ui.menu!="" or placing!="":
		return
	near=nearest_interaction()
	if near.is_empty():
		ui.notice("走近建筑、桥头木牌或农田后按 E")
		return
	var obj=near.obj
	harvesting=false
	match near.type:
		"gate":buy_island(obj)
		"plot":use_plot(obj)
		"station":
			active_station=obj
			match obj.kind:
				"furnace":ui.furnace_menu()
				"market":ui.market_menu()
				"forge":ui.forge_menu()
				"house":ui.home_menu()
				"bench":ui.bench_menu()
				"chest":open_chest()

func harvest():
	cooldown=.34
	if focus.is_empty():
		return
	if energy<1.5:
		ui.notice("体力不足，按 F 吃东西，或回农舍休息")
		sounds.play("no",.3)
		cooldown=.8
		return
	var r=focus
	avatar.face(r.p-p)
	avatar.swing=1.
	energy=maxf(0,energy-1.5)
	dirty=true
	r.hp-=strength()
	var wooden=r.kind in ["tree","berrybush"]
	sounds.play(("timber" if r.kind=="tree" else "leaves") if wooden else ("rock" if r.kind=="stone" else "ore"),.58,.12)
	burst(r.p,Color("#d5b079") if wooden else Color("#b5afb0"),5)
	if r.hp>0:
		var tw=create_tween()
		r.node.rotation.z=.10
		tw.tween_property(r.node,"rotation:z",0.,.18).set_trans(Tween.TRANS_BACK)
		return
	r.node.hide()
	r.rest=rng.randf_range(37.,62.) if wooden else rng.randf_range(52.,85.)
	var k=r.kind
	if k=="tree":
		k="wood"
	if k=="berrybush":
		k="berry"
	var amt=rng.randi_range(2,4) if k in ["wood","stone","berry"] else rng.randi_range(1,2)
	if rng.randf()<.15*int(skills.get("luck",0)):
		amt+=1
	var commons=mini(3,amt)
	for i in commons:
		spawn_drop(k,amt-commons+1 if i==0 else 1,r.p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(.17,.58))
	if k in ["iron_ore","gold_ore","crystal"]:
		spawn_drop("stone",1,r.p+Vector2(.10,.08))
	if rng.randf()<.20:
		spawn_drop("coin",1,r.p+Vector2(.14,.13))
	burst(r.p,Color("#b2ca68") if wooden else Color("#d6c3b2"),8)
	add_xp(int(R.RESOURCES[r.kind][2]))
	focus={}

func drop_mesh(k):
	if drop_models.has(k):
		return drop_models[k]
	var s=Clay.new()
	match k:
		"wood":s.box(Vector3.ZERO,Vector3(.29,.13,.18),Color("#bf8a5b"),Vector3(.10,.15,.16))
		"berry":s.blob(Vector3.ZERO,Vector3.ONE*.20,Color("#da5551"))
		"coin":s.rod(Vector3(0,0,-.04),Vector3(0,0,.04),.135,Color("#f4c64f"),1,12)
		_:s.stone(Vector3(0,-.09,0),Vector3.ONE*.26,Color({"stone":"#ccc2bd","iron_ore":"#d79169","gold_ore":"#edc64c","crystal":"#7cdeef"}.get(k,"#cbbb95")),2)
	drop_models[k]=s.mesh()
	return drop_models[k]

func spawn_drop(k,n,at_pos):
	var m=world.instance(world,drop_mesh(k),Vector3(at_pos.x,.32,at_pos.y))
	pickups.append({"kind":k,"qty":n,"p":at_pos,"node":m,"age":0.0,"magnet":false})
	dirty=true

func update_pickups(dt):
	for i in range(pickups.size()-1,-1,-1):
		var d=pickups[i]
		d.age+=dt
		var dist=d.p.distance_to(p)
		if d.age>.22 and dist<2.85*(1+.5*int(skills.get("magnet",0))):
			d.magnet=true
		if d.magnet:
			d.p=d.p.move_toward(p,dt*(5.6+dist*3.))
		d.node.position=Vector3(d.p.x,.23+absf(sin(d.age*6))*.12+(sin(minf(d.age/.38,1.)*PI)*.40),d.p.y)
		d.node.rotation.y+=dt*2.7
		if d.magnet and d.p.distance_to(p)<.19:
			if d.kind=="coin":
				money+=d.qty
			else:
				put(d.kind,d.qty)
				track(d.kind,d.qty)
			ui.pickup_label(d.kind,d.qty,p+Vector2(rng.randf_range(-.5,.5),-.10))
			sounds.play("pickup",.24,.18)
			d.node.queue_free()
			pickups.remove_at(i)
			dirty=true
			check_goal()

func burst(at_pos,col,n):
	var shape:=BoxMesh.new()
	shape.size=Vector3(.078,.065,.066)
	var m:=StandardMaterial3D.new()
	m.albedo_color=col
	shape.material=m
	for i in n:
		var node=world.instance(world,shape,Vector3(at_pos.x,.53,at_pos.y))
		debris.append({"node":node,"v":Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(1.1,2.4),rng.randf_range(-1.1,1.1)),"time":0.0})
func animate_debris(dt):
	for i in range(debris.size()-1,-1,-1):
		var bit=debris[i]
		bit.time+=dt
		bit.v.y-=dt*6.
		bit.node.position+=bit.v*dt
		bit.node.rotation.x+=dt*4
		bit.node.scale=Vector3.ONE*maxf(.05,1-bit.time/.69)
		if bit.time>.67:
			bit.node.queue_free()
			debris.remove_at(i)

func grow(dt):
	for r in world.resources:
		if r.rest<=0:
			continue
		r.rest=maxf(0,r.rest-dt)
		if r.rest<=0:
			var occupied=false
			for s in world.stations:
				if s.built and (s.p-r.p).abs().x<1.60 and (s.p-r.p).abs().y<1.25:
					occupied=true
					break
			if occupied or p.distance_to(r.p)<1.35:
				r.rest=5.
				continue
			r.hp=R.RESOURCES[r.kind][1]
			r.node.show()
			r.node.scale=Vector3.ONE*.15
			create_tween().tween_property(r.node,"scale",Vector3.ONE*r.size,.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in world.crops:
		if c.kind!="" and c.age<R.GROW_TIME[c.kind] and c.isle in world.owned:
			c.age=minf(R.GROW_TIME[c.kind],c.age+dt)
			update_crop(c)
			dirty=true

func update_crop(c):
	c.node.visible=c.kind!=""
	if not c.node.visible:
		return
	c.node.mesh=world.art.get_mesh(c.kind)
	var fraction=clampf(c.age/R.GROW_TIME[c.kind],0,1)
	c.node.scale=Vector3.ONE*(.31+1.18*floorf(fraction*4)*.25)

func use_plot(c):
	if c.kind=="":
		active_plot=c
		ui.seed_menu()
		return
	if c.age<R.GROW_TIME[c.kind]:
		ui.notice(context_name({"obj":c,"type":"plot"}))
		return
	var k=c.kind
	put(k,2)
	track("harvested")
	if c.get("planted",false):
		track("grown")
	c.kind=""
	c.age=0.
	update_crop(c)
	sounds.play("leaves",.62)
	ui.floating("+2 "+R.NAMES[k],c.p,Color("#ddf4b4"))
	add_xp(5)
	check_goal()
func sow(k):
	if active_plot.is_empty() or active_plot.kind!="" or k not in R.CROPS:
		return
	active_plot.kind=k
	active_plot.age=0.
	active_plot.planted=true
	track("sown")
	update_crop(active_plot)
	sounds.play("soil",.70)
	dismiss()
	ui.notice("种下"+R.NAMES[k])

func eat():
	if energy>=max_energy()-.5:
		ui.notice("体力充沛")
		return
	for k in R.FOOD:
		if count(k)>0:
			put(k,-1)
			energy=minf(max_energy(),energy+R.FOOD[k])
			sounds.play("eat",.70)
			ui.notice("吃下%s，恢复体力"%R.NAMES[k])
			ui.update_hud()
			return
	ui.notice("背包里没有食物，采一些浆果或回农舍休息")
	sounds.play("no",.32)
func rest_home():
	energy=max_energy()
	dirty=true
	sounds.play("ready",.6)
	dismiss()
	save_game()
	ui.notice("休息好了，体力已恢复")

func choose_build(k):
	if k not in R.BUILD or not affords(R.BUILD[k]):
		ui.notice("建造材料不足")
		sounds.play("no",.35)
		return
	ui.close()
	placing=k
	var plane:=BoxMesh.new()
	plane.size=Vector3(2.42,.08,1.80)
	var mat:=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material=mat
	ghost=world.instance(world,plane)
	ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_placement()
	ui.notice("左键放置%s，右键 / Esc 取消"%R.NAMES[k])

func update_placement():
	if placing=="":
		return
	var q=pointer_ground()
	placement=Vector2(snappedf(q.x,.95),snappedf(q.y,.95))
	var ok=placement_valid()
	ghost.position=Vector3(placement.x,.13,placement.y)
	ghost.mesh.material.albedo_color=Color(.39,.99,.45,.67) if ok else Color(1.,.31,.28,.72)
	var id=world.land_at(placement)
	if id!=grid_isle:
		if is_instance_valid(grid):
			grid.queue_free()
		grid=null
		grid_isle=id
		if id>=0:
			grid=draw_grid(id)

func draw_grid(id):
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(1,1,.91,.56)
	st.set_material(mat)
	var c=world.center(id)
	var w=float(R.ISLES[id][3])
	var h=float(R.ISLES[id][4])
	for ix in range(floori((c.x-w/2)/.95)-1,ceili((c.x+w/2)/.95)+1):
		for iz in range(floori((c.y-h/2)/.95)-1,ceili((c.y+h/2)/.95)+1):
			var a=Vector2((ix+.5)*.95,(iz+.5)*.95)
			if not world.in_isle(id,a):
				continue
			for off in [Vector2(.95,0),Vector2(0,.95)]:
				var b=a+off
				if world.in_isle(id,b):
					st.add_vertex(Vector3(a.x,.071,a.y))
					st.add_vertex(Vector3(b.x,.071,b.y))
	var node=world.instance(world,st.commit())
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func placement_valid():
	var delta=(placement-p).abs()
	return (delta.x>1.25 or delta.y>1.0) and world.can_build(placement)
func cancel_build():
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(grid):
		grid.queue_free()
	ghost=null
	grid=null
	grid_isle=-1
	placing=""
	harvesting=false
func commit_build():
	if placing=="" or not placement_valid() or not affords(R.BUILD[placing]):
		ui.notice("这里无法放置，请选绿色空地")
		sounds.play("no",.35)
		return
	var k=placing
	var id=world.land_at(placement)
	pay(R.BUILD[k])
	var st=world.station(id,k,placement-world.center(id),true)
	st.node.scale=Vector3.ONE*.1
	create_tween().tween_property(st.node,"scale",Vector3.ONE,.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst(placement,Color("#e4c995"),12)
	sounds.play("build",.78)
	track("built_"+k)
	cancel_build()
	ui.notice("建成"+R.NAMES[k])
	add_xp(5)
	check_goal()

func enqueue(key:String,qty:int):
	if active_station.is_empty() or active_station.kind!="furnace" or key not in R.RECIPES or qty not in [1,5]:
		return
	var cost=R.RECIPES[key].cost
	if not affords(cost,qty):
		ui.notice("材料不足")
		return
	pay(cost,qty)
	for j in qty:
		active_station.queue.append(key)
	sounds.play("fire",.46)
	ui.furnace_menu()
	ui.update_hud()

func queue_description() -> String:
	if active_station.is_empty() or active_station.queue.is_empty():
		return "制作队列　空闲"
	var s=active_station
	var key=s.queue[0]
	return "制作队列　共 %d 项　　 %s　%.1f / %.1f 秒"%[s.queue.size(),R.NAMES[key],s.work,recipe_time(key)]

func process_queues(dt):
	for s in world.stations:
		if s.queue.is_empty():
			continue
		s.work+=dt
		dirty=true
		while not s.queue.is_empty() and s.work>=recipe_time(s.queue[0]):
			var k=s.queue.pop_front()
			s.work-=recipe_time(k)
			put(k,1)
			track("made_"+k)
			sounds.play("ready",.50 if p.distance_to(s.p)<8 else .27)
			ui.floating("+1 "+R.NAMES[k],p,Color("#ffdfa0"))
			add_xp(2)
			check_goal()
			if s.queue.is_empty():
				s.work=0.
				ui.notice("熔炉完成 · "+R.NAMES[k])
			if ui.menu=="furnace" and active_station.id==s.id:
				ui.furnace_menu()

func bulk_value():
	var total:=0
	for k in R.PRICES:
		if not R.FOOD.has(k):
			total+=count(k)*R.PRICES[k]
	return total
func sell(k,qty):
	if active_station.get("kind","")!="market" or not R.PRICES.has(k):
		return
	var n=clampi(qty,0,count(k))
	var value=int(R.PRICES[k])*n
	if n==0:
		return
	put(k,-n)
	complete_sale(value)
func sell_materials():
	if active_station.get("kind","")!="market":
		return
	var value=bulk_value()
	if value<=0:
		return
	for k in R.PRICES:
		if not R.FOOD.has(k):
			put(k,-count(k))
	complete_sale(value)
func complete_sale(value):
	money+=value
	track("sales",value)
	sounds.play("sell",.77)
	check_goal()
	ui.market_menu()
	ui.update_hud()
	ui.notice("+%d 金币"%value)

func buy_island(g):
	if g.isle not in world.owned or g.target in world.owned:
		return
	var price=island_price()
	if money<price:
		ui.notice("还差 %d 金币，可以去市场出售材料"%(price-money))
		sounds.play("no",.4)
		return
	money-=price
	var new_ids=world.owned.duplicate()
	new_ids.append(g.target)
	world.set_owned(new_ids,g.target)
	sounds.play("island",.83,0.)
	track("bought")
	burst(g.p,Color("#f6d475"),14)
	ui.notice("买下了%s，木桥正在铺设"%R.ISLES[g.target][0])
	add_xp(10)
	check_goal()

func upgrade_tool():
	if active_station.get("kind","")!="forge" or tool_tier>=2:
		return
	var cost=upgrade_cost()
	if not affords(cost):
		return
	pay(cost)
	tool_tier+=1
	avatar.set_tool(tool_tier)
	sounds.play("build",.8)
	track("upgraded")
	check_goal()
	ui.forge_menu()
func mint():
	if active_station.get("kind","")!="forge" or count("gold")<1:
		return
	put("gold",-1)
	money+=25
	track("minted")
	sounds.play("sell",.78)
	ui.forge_menu()
	check_goal()
func open_chest():
	if world.chest_opened:
		ui.notice("这只宝箱已经开启")
		return
	world.set_chest(true)
	money+=90
	put("crystal",4)
	put("gold",2)
	track("chest")
	sounds.play("treasure",.85)
	ui.notice("遗迹宝藏　90 金币、4 水晶、2 金锭")
	add_xp(14)
	check_goal()

func check_goal():
	var before=goal
	var met=[stat("wood")>=4 and stat("stone")>=4,stat("made_brick")>=4,stat("built_market")>0,
		stat("sales")>=25 or (stat("sales")>0 and money>=25),world.owned.size()>1,stat("made_iron")>0,
		tool_tier>0,stat("grown")>0,world.chest_opened,world.owned.size()==R.ISLES.size()]
	while goal<met.size() and met[goal]:
		goal+=1
	if before!=goal:
		dirty=true
		ui.notice("天空群岛已全部点亮！" if goal==10 else "目标完成！")
		sounds.play("ready",.56)
		ui.update_hud()

func pack_state():
	var state={"version":1,"money":money,"level":level,"xp":xp,"energy":energy,"tool":tool_tier,
		"goal":goal,"bag":bag,"skills":skills,"totals":totals,"pending":pending,"choices":skill_choices,
		"owned":world.owned,"player":[p.x,p.y],"facing":avatar.heading,"zoom":zoom,
		"chest":world.chest_opened,"music":sounds.music_level,"fx":sounds.fx_level,
		"stations":[],"nodes":[],"plots":[],"drops":[]}
	for s in world.stations:
		state.stations.append({"isle":s.isle,"kind":s.kind,"p":[s.p.x,s.p.y],"built":s.built,"queue":s.queue,"work":s.work})
	for r in world.resources:
		state.nodes.append([r.hp,r.rest])
	for c in world.crops:
		state.plots.append([c.kind,c.age,c.get("planted",false)])
	for d in pickups:
		state.drops.append([d.kind,d.qty,d.p.x,d.p.y])
	return state

func save_game() -> bool:
	if not started:
		return true
	var temp=SAVE+".tmp"
	var f=FileAccess.open(temp,FileAccess.WRITE)
	if f==null:
		return false
	f.store_string(JSON.stringify(pack_state()))
	f.flush()
	var err=f.get_error()
	f.close()
	if err!=OK:
		return false
	var target=ProjectSettings.globalize_path(SAVE)
	var backup=target+".bak"
	if FileAccess.file_exists(SAVE):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:
			return false
		if DirAccess.rename_absolute(target,backup)!=OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),target)!=OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup,target)
		return false
	dirty=false
	return true

func read_save() -> Dictionary:
	for file in [SAVE,SAVE+".bak"]:
		if not FileAccess.file_exists(file):
			continue
		var data=JSON.parse_string(FileAccess.get_file_as_string(file))
		if data is Dictionary and data.get("version",0)==1 and data.get("owned") is Array and data.get("bag") is Dictionary:
			return data
	return {}

func restore(data):
	money=maxi(0,int(data.get("money",0)))
	level=maxi(1,int(data.get("level",1)))
	xp=clampi(int(data.get("xp",0)),0,next_xp()-1)
	tool_tier=clampi(int(data.get("tool",0)),0,2)
	goal=clampi(int(data.get("goal",0)),0,10)
	bag=data.bag.duplicate()
	skills=data.get("skills",{}).duplicate()
	energy=clampf(data.get("energy",100.),0,max_energy())
	totals=data.get("totals",{}).duplicate()
	pending=maxi(0,int(data.get("pending",0)))
	skill_choices=data.get("choices",[]).filter(func(k):return k in R.SKILLS)
	var ids=[0]
	for value in data.owned:
		var id=int(value)
		if id>0 and id<R.ISLES.size() and id not in ids:
			ids.append(id)
	world.set_owned(ids)
	world.set_chest(data.get("chest",false))
	var buildings=data.get("stations",[])
	for i in buildings.size():
		var src=buildings[i]
		var s:Dictionary
		if src.get("built",false):
			var id=int(src.isle)
			if id not in ids or src.kind not in R.BUILD:
				continue
			s=world.station(id,src.kind,Vector2(src.p[0],src.p[1])-world.center(id),true)
		elif i<world.stations.size():
			s=world.stations[i]
		else:
			continue
		s.queue=src.get("queue",[]).filter(func(k):return k in R.RECIPES)
		s.work=maxf(0,src.get("work",0.))
	var nodes=data.get("nodes",[])
	for i in mini(world.resources.size(),nodes.size()):
		var r=world.resources[i]
		r.rest=maxf(0,nodes[i][1])
		r.hp=nodes[i][0]
		r.node.visible=r.rest<=0
	var plots=data.get("plots",[])
	for i in mini(world.crops.size(),plots.size()):
		var c=world.crops[i]
		var item=plots[i]
		c.kind=item[0] if item[0] in R.CROPS else ""
		c.age=maxf(0,item[1])
		c.planted=item[2] if item.size()>2 else false
		update_crop(c)
	for d in data.get("drops",[]):
		if d.size()==4 and (d[0] in R.PRICES or d[0]=="coin"):
			spawn_drop(d[0],int(d[1]),Vector2(d[2],d[3]))
	var pos=data.get("player",[0,.85])
	var from_save=Vector2(pos[0],pos[1])
	if world.walkable(from_save):
		p=from_save
	avatar.heading=data.get("facing",0.)
	zoom=clampf(data.get("zoom",12.8),8.5,21.)
	sounds.set_levels(data.get("music",.56),data.get("fx",.78))
