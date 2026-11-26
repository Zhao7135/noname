extends CanvasLayer

const R=preload("res://scripts/rules.gd")
const INK=Color("#49351f")
const MUTED=Color("#806c4f")
const PAPER=Color("#fff4d9")
const GOLD=Color("#ffd877")
const GREEN=Color("#b3df83")
var game
var root:=Control.new()
var overlay:=Control.new()
var hud:=Control.new()
var modal:=Control.new()
var regular:=SystemFont.new()
var bold:=SystemFont.new()
var coin: Label
var rank_label: Label
var exp_bar: ProgressBar
var power_bar: ProgressBar
var exp_value: Label
var power_value: Label
var task_index: Label
var task_text: Label
var tool_title: Label
var tool_value: Label
var slots:=HBoxContainer.new()
var prompt: Button
var target: PanelContainer
var target_text: Label
var target_hp: ProgressBar
var furnace_badge: Label
var toast: Label
var toast_time:=0.0
var menu:=""
var content: VBoxContainer
var panel: PanelContainer
var sign_labels: Array=[]
var floats: Array=[]
var quicks: Array[Callable]=[]
var slot_key:=""
var queue_status:Label
var title_box:Control

func setup(owner_game):
	game=owner_game
	regular.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","PingFang SC","Arial"])
	bold.font_names=regular.font_names
	bold.font_weight=700
	add_child(root)
	full(root)
	pass_mouse(root)
	root.add_child(overlay)
	full(overlay)
	pass_mouse(overlay)
	root.add_child(hud)
	full(hud)
	pass_mouse(hud)
	root.add_child(modal)
	full(modal)
	pass_mouse(modal)
	build_hud()
	for gate in game.world.gates:
		var p=pill("",14,Color("#ffe6a1"))
		overlay.add_child(p)
		sign_labels.append(p)
		p.visible=false
	hud.visible=false

func full(c:Control):
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func pass_mouse(c:Control):
	c.mouse_filter=Control.MOUSE_FILTER_IGNORE

func anchor(c:Control,ax,ay,x,y,w,h):
	c.anchor_left=ax
	c.anchor_right=ax
	c.anchor_top=ay
	c.anchor_bottom=ay
	c.offset_left=x
	c.offset_top=y
	c.offset_right=x+w
	c.offset_bottom=y+h

func skin(bg:Color,edge:=Color("#886e50"),radius:=12,margin:=9,shadow:=true) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left=margin
	s.content_margin_right=margin
	s.content_margin_top=margin
	s.content_margin_bottom=margin
	if shadow:
		s.shadow_color=Color(0.18,.13,.09,.23)
		s.shadow_size=3
		s.shadow_offset=Vector2(0,3)
	return s

func card(bg:=PAPER,margin:=10,radius:=12) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",skin(bg,Color("#8d7354"),radius,margin))
	pass_mouse(p)
	return p

func label(txt:String,size:int=17,heavy:bool=false,col:Color=INK) -> Label:
	var l:=Label.new()
	l.text=txt
	l.add_theme_font_override("font",bold if heavy else regular)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",col)
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	pass_mouse(l)
	return l

func btn(txt:String,call:Callable,bg:Color=PAPER,sz:int=17) -> Button:
	var b:=Button.new()
	b.text=txt
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",bold)
	b.add_theme_font_size_override("font_size",sz)
	for mode in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		b.add_theme_color_override(mode,INK)
	b.add_theme_color_override("font_disabled_color",Color("#9d927c"))
	for mode in ["normal","pressed","hover","disabled"]:
		var color=bg
		if mode=="pressed":
			color=bg.darkened(.09)
		if mode=="hover":
			color=bg.lightened(.17)
		if mode=="disabled":
			color=Color("#e7ddc7")
		var style=skin(color,Color("#aa8c65"),9,6,mode=="normal")
		style.content_margin_left=12
		style.content_margin_right=12
		b.add_theme_stylebox_override(mode,style)
	b.pressed.connect(func():game.sounds.play("tap",.35);call.call())
	return b

func icon(key:String,size:int) -> TextureRect:
	var texture:=TextureRect.new()
	texture.texture=load("res://art/icons/%s.png"%key)
	texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.custom_minimum_size=Vector2(size,size)
	pass_mouse(texture)
	return texture

func vbox(gap:=4) -> VBoxContainer:
	var c:=VBoxContainer.new()
	c.add_theme_constant_override("separation",gap)
	pass_mouse(c)
	return c
func hbox(gap:=6) -> HBoxContainer:
	var c:=HBoxContainer.new()
	c.add_theme_constant_override("separation",gap)
	pass_mouse(c)
	return c
func expand(c:Control):
	c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func clear(c:Node):
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()

func pill(txt:String,sz:int,bg:Color) -> Label:
	var l=label(txt,sz,true)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var s=skin(bg,Color("#ae925e"),8,4)
	s.content_margin_left=9
	s.content_margin_right=9
	l.add_theme_stylebox_override("normal",s)
	return l

func bar(col:Color) -> ProgressBar:
	var p:=ProgressBar.new()
	p.show_percentage=false
	p.custom_minimum_size=Vector2(126,17)
	pass_mouse(p)
	p.add_theme_stylebox_override("background",skin(Color("#cbb99b"),Color("#8b765e"),8,0,false))
	var f=skin(col,col.darkened(.20),8,0,false)
	f.set_border_width_all(1)
	p.add_theme_stylebox_override("fill",f)
	return p

func bar_text(p):
	var l=label("",12,true,Color.WHITE)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color",Color("#776e57"))
	l.add_theme_constant_override("outline_size",3)
	p.add_child(l)
	full(l)
	return l

func build_hud():
	var stats=card(PAPER,8)
	hud.add_child(stats)
	anchor(stats,0,0,13,12,206,111)
	var col=vbox(3)
	stats.add_child(col)
	var cash=hbox(6)
	col.add_child(cash)
	cash.add_child(icon("coin",30))
	coin=label("0",23,true)
	cash.add_child(coin)
	var sep:=HSeparator.new()
	col.add_child(sep)
	var row=hbox(8)
	col.add_child(row)
	rank_label=pill("1",17,GOLD)
	row.add_child(rank_label)
	var xp_field=vbox(0)
	expand(xp_field)
	row.add_child(xp_field)
	xp_field.add_child(label("经验",12,true,MUTED))
	exp_bar=bar(Color("#79c4ee"))
	xp_field.add_child(exp_bar)
	exp_value=bar_text(exp_bar)
	var energy_row=hbox(10)
	col.add_child(energy_row)
	energy_row.add_child(icon("energy",28))
	power_bar=bar(Color("#93d359"))
	expand(power_bar)
	power_bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	energy_row.add_child(power_bar)
	power_value=bar_text(power_bar)
	var quest=card(PAPER,8)
	hud.add_child(quest)
	anchor(quest,.5,0,-12,12,0,0)
	var flow=hbox(10)
	quest.add_child(flow)
	flow.add_child(label("⚑",28,true,Color("#bd6642")))
	var desc=vbox(0)
	flow.add_child(desc)
	task_index=label("",12,true,MUTED)
	desc.add_child(task_index)
	task_text=label("",16,true)
	desc.add_child(task_text)
	var toolpanel=card(PAPER,6)
	hud.add_child(toolpanel)
	anchor(toolpanel,0,1,13,-75,145,62)
	var toolrow=hbox(7)
	toolpanel.add_child(toolrow)
	toolrow.add_child(icon("pick",48))
	var tools=vbox(0)
	toolrow.add_child(tools)
	tools.add_child(label("当前工具",12,true,MUTED))
	tool_title=label("石镐",19,true)
	tools.add_child(tool_title)
	tool_value=label("",12,false,MUTED)
	tools.add_child(tool_value)
	var center_slots:=CenterContainer.new()
	hud.add_child(center_slots)
	anchor(center_slots,.5,1,-250,-66,500,56)
	pass_mouse(center_slots)
	center_slots.add_child(slots)
	slots.add_theme_constant_override("separation",3)
	pass_mouse(slots)
	var commands=hbox(4)
	hud.add_child(commands)
	anchor(commands,1,1,-319,-42,306,31)
	for pair in [["E  交互","act"],["B  建造","build"],["F  吃东西","eat"],["H  帮助","help"]]:
		var action:String=pair[1]
		var b=btn(pair[0],func():game.command(action),PAPER,13)
		commands.add_child(b)
	prompt=btn("",func():game.interact(),Color("#fff0cd"),15)
	hud.add_child(prompt)
	prompt.visible=false
	target=card(PAPER,5,8)
	overlay.add_child(target)
	var tb=vbox(2)
	target.add_child(tb)
	target_text=label("",14,true)
	tb.add_child(target_text)
	target_hp=bar(Color("#91ca50"))
	target_hp.custom_minimum_size=Vector2(79,10)
	tb.add_child(target_hp)
	target.visible=false
	furnace_badge=pill("",13,PAPER)
	overlay.add_child(furnace_badge)
	furnace_badge.hide()
	toast=pill("",15,Color("#5d4731"))
	toast.add_theme_color_override("font_color",Color("#fff5d5"))
	hud.add_child(toast)
	toast.visible=false

func update_hud():
	coin.text=str(game.money)
	rank_label.text=str(game.level)
	exp_bar.max_value=game.next_xp()
	exp_bar.value=game.xp
	exp_value.text="%d / %d"%[game.xp,game.next_xp()]
	power_bar.max_value=game.max_energy()
	power_bar.value=game.energy
	power_value.text="%d / %d"%[roundi(game.energy),game.max_energy()]
	task_index.text="目标  %d / 10"%mini(game.goal+1,10) if game.goal<10 else "群岛已点亮"
	task_text.text=R.GOALS[game.goal] if game.goal<10 else "十一座岛屿已连通，自由经营你的天空家园"
	tool_title.text=["石镐","铁镐","金镐"][game.tool_tier]
	tool_value.text="采集力 %.1f"%game.strength()
	var key=JSON.stringify(game.bag)
	if key!=slot_key:
		slot_key=key
		clear(slots)
		for k in R.ORDER:
			if game.count(k)<=0:
				continue
			var p=card(Color("#fff0d1"),2,8)
			p.tooltip_text="%s × %d"%[R.NAMES[k],game.count(k)]
			slots.add_child(p)
			var floor:=Control.new()
			floor.custom_minimum_size=Vector2(37,38)
			p.add_child(floor)
			pass_mouse(floor)
			var im=icon(k,33)
			floor.add_child(im)
			anchor(im,.5,.5,-16,-18,33,33)
			var n=label(str(game.count(k)),13,true,Color.WHITE)
			floor.add_child(n)
			n.add_theme_color_override("font_outline_color",Color("#684a31"))
			n.add_theme_constant_override("outline_size",4)
			n.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			anchor(n,1,1,-34,-19,34,19)

func notice(txt):
	toast.text=txt
	toast.reset_size()
	toast.visible=true
	toast_time=2.65

func floating(txt,p,col):
	var l=label(txt,17,true,col)
	l.add_theme_color_override("font_outline_color",Color("#665640"))
	l.add_theme_constant_override("outline_size",4)
	overlay.add_child(l)
	floats.append({"l":l,"p":p,"age":0.0})

func pickup_label(k,qty,p):
	var title="金币" if k=="coin" else R.NAMES[k]
	for f in floats:
		if f.get("item","")==k and f.age<.42:
			f.total+=qty
			f.l.text="+%d %s"%[f.total,title]
			return
	floating("+%d %s"%[qty,title],p,Color("#ffdb70") if k=="coin" else Color("#fff6d7"))
	floats.back().item=k
	floats.back().total=qty

func tick(dt,near:Dictionary,focus:Dictionary):
	var cam=game.camera
	var vp=root.size
	var labels_on=game.started and menu=="" and game.placing==""
	furnace_badge.hide()
	if labels_on:
		for s in game.world.stations:
			if s.queue.is_empty() or s.p.distance_to(game.p)>9.0:
				continue
			var ratio=clampf(s.work/game.recipe_time(s.queue[0]),0.,1.)
			furnace_badge.text="%s  %d%%"%[R.NAMES[s.queue[0]],roundi(ratio*100)]
			furnace_badge.reset_size()
			furnace_badge.show()
			furnace_badge.position=cam.unproject_position(Vector3(s.p.x,1.86,s.p.y))-Vector2(furnace_badge.size.x*.5,furnace_badge.size.y)
			break
	for i in sign_labels.size():
		var l=sign_labels[i]
		var g=game.world.gates[i]
		l.visible=labels_on and g.node.visible and g.p.distance_to(game.p)<22
		if l.visible:
			var cost=game.island_price()
			var pos=cam.unproject_position(Vector3(g.p.x,1.31,g.p.y))
			if pos.y<42 or pos.y>vp.y-9 or pos.x<18 or pos.x>vp.x-18:
				l.hide()
				continue
			l.text="◈  %s · %d 金币"%[R.ISLES[g.target][0],cost]
			l.add_theme_color_override("font_color",Color("#527138") if game.money>=cost else INK)
			l.reset_size()
			l.position=Vector2(clampf(pos.x-l.size.x*.5,4,vp.x-l.size.x-4),pos.y-l.size.y)
	target.visible=labels_on and not focus.is_empty() and (game.harvesting or focus.hp<R.RESOURCES[focus.kind][1] or game.pointer_ground().distance_to(focus.p)<1.45)
	if target.visible:
		target_text.text=R.RESOURCES[focus.kind][0]
		target_hp.max_value=R.RESOURCES[focus.kind][1]
		target_hp.value=focus.hp
		target.position=cam.unproject_position(Vector3(focus.p.x,2.1 if focus.kind=="tree" else 1.2,focus.p.y))-Vector2(target.size.x*.5,target.size.y+4)
	prompt.visible=labels_on and not near.is_empty()
	if prompt.visible:
		prompt.text="E   "+game.context_name(near)
		prompt.reset_size()
		prompt.position=Vector2((vp.x-prompt.size.x)*.5,vp.y-105)
	if toast_time>0:
		toast_time-=dt
		toast.position=Vector2((vp.x-toast.size.x)*.5,79)
		toast.visible=toast_time>0
	for i in range(floats.size()-1,-1,-1):
		var f=floats[i]
		f.age+=dt
		f.l.position=cam.unproject_position(Vector3(f.p.x,1.1+f.age*1.12,f.p.y))-Vector2(f.l.size.x*.5,14)
		f.l.modulate.a=clampf((1.32-f.age)*3.1,0.,1.)
		f.l.visible=menu==""
		if f.age>=1.35:
			f.l.queue_free()
			floats.remove_at(i)
	if menu=="furnace" and is_instance_valid(queue_status):
		queue_status.text=game.queue_description()

func show_title(has_save):
	close()
	menu="title"
	hud.hide()
	title_box=CenterContainer.new()
	modal.add_child(title_box)
	full(title_box)
	pass_mouse(title_box)
	var c=vbox(9)
	c.alignment=BoxContainer.ALIGNMENT_CENTER
	title_box.add_child(c)
	var title=label("天空物语",82,true,Color("#fff0c5"))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color",Color("#563e28"))
	title.add_theme_constant_override("outline_size",13)
	title.add_theme_color_override("font_shadow_color",Color("#745733"))
	title.add_theme_constant_override("shadow_offset_y",5)
	c.add_child(title)
	var sub=label("采集  ·  建造  ·  买岛",23,true,Color("#fff3d1"))
	sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color",Color("#634f35"))
	sub.add_theme_constant_override("outline_size",5)
	c.add_child(sub)
	var spacer=Control.new()
	spacer.custom_minimum_size.y=18
	c.add_child(spacer)
	var buttons=hbox(12)
	buttons.alignment=BoxContainer.ALIGNMENT_CENTER
	c.add_child(buttons)
	buttons.add_child(btn("继续游戏" if has_save else "从家园启程",func():game.start_game(has_save),GOLD,19))
	if has_save:
		buttons.add_child(btn("新游戏",func():confirm_new(),PAPER,16))

func close():
	clear(modal)
	menu=""
	quicks.clear()
	queue_status=null
	content=null
	panel=null
	game.harvesting=false

func dialog(key:String,heading:String,width:int,subtitle:="",can_close:=true):
	close()
	menu=key
	var veil:=ColorRect.new()
	veil.color=Color(.12,.11,.10,.40)
	modal.add_child(veil)
	full(veil)
	var mid:=CenterContainer.new()
	veil.add_child(mid)
	full(mid)
	pass_mouse(mid)
	panel=card(PAPER,16,16)
	mid.add_child(panel)
	panel.custom_minimum_size.x=width
	content=vbox(12)
	panel.add_child(content)
	var header=hbox(8)
	content.add_child(header)
	var title=label(heading,27,true)
	expand(title)
	header.add_child(title)
	if can_close:
		header.add_child(btn("×",func():game.dismiss(),Color("#f0dfb9"),17))
	if subtitle!="":
		content.add_child(label(subtitle,15,false,MUTED))
	var rule:=HSeparator.new()
	content.add_child(rule)

func footer(txt="E  或  Esc  关闭"):
	var l=label(txt,13,false,MUTED)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(l)

func confirm_new():
	dialog("confirm","重新开始",390,"现有进度会保留为一份备份。",false)
	var row=hbox(10)
	content.add_child(row)
	row.add_child(btn("返回",func():show_title(true)))
	row.add_child(btn("新建家园",func():game.start_game(false),GOLD))

func build_menu():
	dialog("build","建造",620,"选择一座建筑，然后在已拥有的岛上点击放置。")
	var row=hbox(10)
	content.add_child(row)
	for key in ["furnace","market","forge"]:
		var k:String=key
		var ok=game.affords(R.BUILD[k])
		var action=func():game.choose_build(k)
		build_card(row,k,R.NAMES[k],R.BUILD_DESC[k],game.cost_text(R.BUILD[k]),"点击建造" if ok else "材料不足",action,ok)
		quicks.append(action)
	footer("1–3  快速选择     Esc  关闭")

func build_card(row,key,title,desc,small,action_text,action,enabled):
	var p=card(Color("#faedcf"),9)
	expand(p)
	row.add_child(p)
	var c=vbox(7)
	p.add_child(c)
	var index=label(str(row.get_child_count()),12,true,MUTED)
	c.add_child(index)
	var i=icon(key,64)
	i.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	c.add_child(i)
	var h=label(title,23,true)
	h.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(h)
	var d=label(desc,14,false,MUTED)
	d.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(d)
	if small!="":
		var needed=label(small,14,true)
		needed.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(needed)
	var b=btn(action_text,action,GREEN if enabled else Color("#eac3ac"),16)
	b.disabled=not enabled
	c.add_child(b)

func level_menu():
	dialog("level","★ 升级！   Lv %d  ★"%game.level,638,"选择一项技能强化你的岛民。",false)
	var veil:ColorRect=modal.get_child(0)
	var shader:=Shader.new();shader.code="""shader_type canvas_item;
		void fragment(){vec2 p=UV-vec2(.5);float a=atan(p.y,p.x);float r=length(p);
		float ray=.5+.5*cos(a*14.+TIME*.4);COLOR=mix(vec4(.12,.10,.09,.53),vec4(.9,.71,.30,.22),ray*(1.-smoothstep(.08,.74,r)));}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	veil.material=mat
	for i in 24:
		var speck:=ColorRect.new()
		speck.color=[GOLD,GREEN,Color("#e8a795"),Color("#a7d5e5")][i%4]
		pass_mouse(speck)
		speck.size=Vector2(4+(i%3),5)
		veil.add_child(speck)
		veil.move_child(speck,0)
		var origin=Vector2(fmod(i*.61803,1.)*root.size.x,root.size.y*fmod(i*.382+.1,1.))
		speck.position=origin
		speck.rotation=i
		var t=speck.create_tween().set_loops()
		t.tween_property(speck,"position",origin+Vector2(sin(i)*34,105),1.8+(i%5)*.2)
		t.tween_callback(func():speck.position=origin)
	var row=hbox(10)
	content.add_child(row)
	for key in game.skill_choices:
		var k:String=key
		var call=func():game.take_skill(k)
		build_card(row,k,R.SKILLS[k][0],R.SKILLS[k][1],"","新技能" if game.skills.get(k,0)==0 else "再次强化",call,true)
		quicks.append(call)
	footer("1–3  快速选择")

func furnace_menu():
	dialog("furnace","熔炉",555,"烧制砖块、冶炼矿石")
	for k in R.RECIPES:
		var key:String=k
		var recipe=R.RECIPES[key]
		var row=hbox(9)
		content.add_child(row)
		row.add_child(icon(key,40))
		var col=vbox(0)
		expand(col)
		row.add_child(col)
		col.add_child(label(R.NAMES[key],17,true))
		col.add_child(label("%.1f 秒"%game.recipe_time(key),13,false,MUTED))
		row.add_child(label(game.cost_text(recipe.cost,true),14,true))
		for n in [1,5]:
			var qty:int=n
			var b=btn("×%d"%qty,func():game.enqueue(key,qty),GREEN if qty==1 else Color("#f3deaf"))
			b.disabled=not game.affords(recipe.cost,qty)
			row.add_child(b)
	queue_status=label("",15,true,MUTED)
	queue_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(queue_status)
	queue_status.text=game.queue_description()
	footer()

func market_menu():
	dialog("market","市场     ◈ %d"%game.money,660,"出售物品换取金币")
	var scroll:=ScrollContainer.new()
	content.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",7)
	expand(grid)
	scroll.add_child(grid)
	var amount=0
	for k in R.ORDER:
		if game.count(k)<=0:
			continue
		amount+=1
		var key:String=k
		var row=hbox(3)
		grid.add_child(row)
		row.add_child(icon(key,34))
		var desc=vbox(0)
		expand(desc)
		row.add_child(desc)
		desc.add_child(label(R.NAMES[key],15,true))
		desc.add_child(label("拥有 ×%d"%game.count(key),12,false,MUTED))
		row.add_child(label("◈%d"%R.PRICES[key],14,true))
		row.add_child(btn("卖 1",func():game.sell(key,1),PAPER,13))
		row.add_child(btn("全部",func():game.sell(key,game.count(key)),GREEN,13))
	scroll.custom_minimum_size.y=clampf(ceili(amount/2.)*47.,48.,248.)
	if amount==0:
		grid.add_child(label("背包里还没有可出售的物品。",16,false,MUTED))
	var total=game.bulk_value()
	var b=btn("出售材料  +%d"%total,func():game.sell_materials(),GREEN,16)
	b.disabled=total==0
	content.add_child(b)
	footer()

func forge_menu():
	dialog("forge","锻造台",495,"工具强化与金币铸造")
	if game.tool_tier<2:
		var cost=game.upgrade_cost()
		content.add_child(label("打造%s　 %s"%[["铁镐","金镐"][game.tool_tier],game.cost_text(cost)],18,true))
		var up=btn("锻造工具",func():game.upgrade_tool(),GREEN)
		up.disabled=not game.affords(cost)
		content.add_child(up)
	else:
		content.add_child(label("金镐已打造",18,true))
	var mint=btn("铸造 25 金币　·　消耗 1 金锭",func():game.mint(),GOLD)
	mint.disabled=game.count("gold")<1
	content.add_child(mint)
	footer()

func seed_menu():
	dialog("seed","播种",480,"选择要种在这块田里的作物。")
	var row=hbox(10)
	content.add_child(row)
	for k in R.CROPS:
		var key:String=k
		var c=vbox(5)
		expand(c)
		row.add_child(c)
		c.add_child(icon(key,49))
		var act=func():game.sow(key)
		c.add_child(btn(R.NAMES[key],act,GREEN))
		c.add_child(label("%d 秒成熟"%R.GROW_TIME[key],14,false,MUTED))
		quicks.append(act)
	footer("1–3  选择种子     Esc  关闭")

func home_menu():
	dialog("home","农舍",420,"在云上的家休息片刻，恢复全部体力。")
	content.add_child(btn("休息并存档",func():game.rest_home(),GREEN))
	footer()

func bench_menu():
	dialog("bench","工作台",440,"查看工具与岛民技能")
	content.add_child(label("当前工具　%s　　采集力 %.1f"%[["石镐","铁镐","金镐"][game.tool_tier],game.strength()],18,true))
	var learned: Array=[]
	for k in R.SKILLS:
		if game.skills.get(k,0)>0:
			learned.append("%s ×%d"%[R.SKILLS[k][0],game.skills[k]])
	content.add_child(label("已学技能　"+"、".join(learned) if learned.size() else "获得经验升级后即可挑选技能。",15,false,MUTED))
	content.add_child(btn("打开建造菜单",func():build_menu(),GREEN))
	footer()

func help_menu():
	dialog("help","岛民手册",568,"目标 %d / 10　　已连通 %d / 11 座岛"%[mini(10,game.goal+1),game.world.owned.size()])
	for pair in [["WASD / 方向键","移动，沿木桥前往相邻岛屿"],["按住鼠标左键","靠近树、浆果丛或矿石连续采集，掉落物自动吸附"],
			["E","使用附近的设施、购买岛屿、耕种或打开宝箱"],["B / F","打开建造菜单 / 食用背包里的食物补充能量"],
			["M / 滚轮","查看群岛全景 / 调整镜头远近"],["Esc","暂停、调节音量或保存返回标题"]]:
		var row=hbox(8)
		content.add_child(row)
		var key=label(pair[0],15,true)
		key.custom_minimum_size.x=135
		row.add_child(key)
		row.add_child(label(pair[1],15))
	footer("H  或  Esc  返回")

func pause_menu():
	dialog("pause","暂停",420)
	for pair in [["音乐",true],["音效",false]]:
		var m:bool=pair[1]
		var row=hbox(16)
		content.add_child(row)
		row.add_child(label(pair[0],17,true))
		var slider:=HSlider.new()
		slider.min_value=0
		slider.max_value=100
		slider.step=1
		expand(slider)
		row.add_child(slider)
		slider.value=(game.sounds.music_level if m else game.sounds.fx_level)*100
		slider.value_changed.connect(func(v):
			game.sounds.set_levels(v/100 if m else game.sounds.music_level,game.sounds.fx_level if m else v/100)
			game.dirty=true)
	content.add_child(btn("继续游戏",func():game.dismiss(),GREEN))
	content.add_child(btn("岛民手册",func():help_menu()))
	content.add_child(btn("保存并返回标题",func():game.to_title()))

func overview():
	close()
	menu="map"
	hud.hide()
	var b=btn("返回岛民身边    M",func():game.dismiss(),PAPER)
	modal.add_child(b)
	anchor(b,.5,1,-95,-66,190,43)
	for i in game.world.islands.size():
		var name_tag=pill(R.ISLES[i][0]+("  ✓" if i in game.world.owned else ""),14,PAPER if i in game.world.owned else Color("#d9d9c4"))
		modal.add_child(name_tag)
		name_tag.set_meta("isle",i)

func map_positions():
	for node in modal.get_children():
		if node.has_meta("isle"):
			var p=game.world.center(node.get_meta("isle"))
			node.position=game.camera.unproject_position(Vector3(p.x,1,p.y))-node.size*.5
