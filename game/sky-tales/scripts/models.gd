extends RefCounted

const Clay = preload("res://scripts/sculpt.gd")
var library := {}

func get_mesh(kind: String) -> ArrayMesh:
	if library.has(kind):
		return library[kind]
	var s = Clay.new()
	var rand := RandomNumberGenerator.new()
	rand.seed = absi(kind.hash())+57
	match kind:
		"house": house(s)
		"furnace": furnace(s)
		"market": market(s)
		"forge": forge(s)
		"bench": bench(s)
		"crate": crate(s)
		"barrel": barrel(s)
		"logs": logs(s)
		"stump": stump(s)
		"fence": fence(s)
		"sign": signpost(s)
		"cart": cart(s)
		"cave": cave(s)
		"pillar": pillar(s,rand)
		"arch": arch(s)
		"chest","chest_open": chest(s,kind=="chest_open")
		"pad": lily(s)
		"grass","flowers","mushrooms","pebbles","yellow","fern": ground_detail(s,kind,rand)
		"crop_soil": soil(s)
		"carrot","turnip","cabbage": crop(s,kind)
		"scarecrow": scarecrow(s)
		"berrybush": bush(s,true)
		"bush": bush(s,false)
		"stone","iron_ore","gold_ore","crystal": ore(s,kind,rand)
		_: tree(s,rand)
	var m = s.mesh()
	library[kind]=m
	return m

func tree(s,rand):
	var lean := float(rand.randf_range(-.15,.15))
	s.rod(Vector3(0,.02,0),Vector3(lean,1.57,0),.225,Color("#805538"),.72,9)
	s.rod(Vector3(lean*.5,.76,0),Vector3(-.42,1.49,.03),.12,Color("#88593d"),.6)
	var greens = ["#7cae51","#79ab4b","#84b45a","#70a750"]
	var green = Color(greens[rand.randi_range(0,3)])
	s.canopy(Vector3(lean,1.91,0),Vector3(1.13,.95,1.07),green,rand)

func bush(s,berries):
	s.blob(Vector3(0,.48,0),Vector3(1.65,1.06,1.42),Color("#6aa947"))
	s.blob(Vector3(-.37,.50,.13),Vector3(.85,.89,.88),Color("#77b44b"))
	s.blob(Vector3(.24,.71,-.16),Vector3(.92,.75,.86),Color("#72ad48"))
	if berries:
		for p in [Vector3(-.47,.83,.34),Vector3(.16,.99,.12),Vector3(.52,.69,.39),Vector3(-.19,.60,.63),Vector3(.45,.83,-.34)]:
			s.blob(p,Vector3.ONE*.19,Color("#da5445"))
			s.blob(p+Vector3(-.03,.06,.04),Vector3.ONE*.055,Color("#f8986a"))

func ore(s,kind,rand):
	var rock_color = Color("#9993a0")
	s.stone(Vector3(-.15,0,-.06),Vector3(.99,.87,.88),rock_color,14)
	s.stone(Vector3(.38,0,.17),Vector3(.75,.55,.68),rock_color.lightened(.09),78)
	s.stone(Vector3(-.58,0,.29),Vector3(.46,.35,.46),rock_color.darkened(.12),38)
	if kind=="stone":
		return
	var col = Color({"iron_ore":"#d98a53","gold_ore":"#efc442","crystal":"#63d5ed"}[kind])
	for i in 7:
		var angle=i*TAU/7
		var p=Vector3(-.1+cos(angle)*.36,.35+rand.randf_range(.03,.19),sin(angle)*.31)
		var size: float=rand.randf_range(.23,.36)
		if kind=="crystal":
			var tip=p+Vector3(cos(angle)*.12,size*1.45,sin(angle)*.1)
			s.rod(p,tip,size*.44,col.lightened(rand.randf_range(0,.25)),.86,5)
			s.rod(tip,tip+Vector3(0,.12,0),size*.37,Color("#b6f4f4"),.02,5)
		else:
			s.stone(p,Vector3(size,size*.8,size),col.lightened(rand.randf_range(0,.1)),10+i)

func house(s):
	var plaster=Color("#f3dfb4")
	var timber=Color("#886442")
	s.box(Vector3(0,.11,0),Vector3(2.78,.24,2.27),Color("#aaa194"))
	s.box(Vector3(0,.94,0),Vector3(2.66,1.53,2.13),plaster)
	for z in [-1.067,1.067]:
		s.tri(Vector3(-1.33,1.69,z),Vector3(1.33,1.69,z),Vector3(0,2.73,z),plaster,Vector3(0,0,z))
	for side in [-1,1]:
		var theta=-side*.65
		s.box(Vector3(.77*side,2.12,0),Vector3(1.98,.17,2.65),Color("#b86542"),Vector3(0,0,theta))
		for row in 6:
			var x: float = .07+row*.276
			for c in 9:
				var z: float=-1.2+c*.302+(row%2)*.04
				var tc=Color(["#e38b53","#d97c47","#e9955d","#e58a50"][(c+row*3+abs(c*row))%4])
				s.box(Vector3(x*side,2.77-x*.762,z),Vector3(.38,.104,.285),tc,Vector3(0,0,theta))
	for z in [-.9,.92]:
		for x in [-1.28,1.28]:
			s.box(Vector3(x,.84,z),Vector3(.13,1.36,.13),Color("#caaf8c"))
	s.box(Vector3(0,.57,1.095),Vector3(.68,1.14,.13),timber)
	s.blob(Vector3(0,1.11,1.10),Vector3(.68,.43,.13),timber)
	for x in [-.22,-.05,.13,.25]:
		s.box(Vector3(x,.63,1.169),Vector3(.13,.89,.028),Color("#ba8c60"))
	s.blob(Vector3(.20,.63,1.20),Vector3.ONE*.08,Color("#e8bb57"))
	for x in [-.89,.89]:
		s.box(Vector3(x,1.04,1.083),Vector3(.61,.65,.12),Color("#c9b38e"))
		s.box(Vector3(x,1.04,1.16),Vector3(.48,.51,.03),Color("#a9d2db"))
		s.box(Vector3(x,1.04,1.18),Vector3(.052,.53,.03),plaster)
		s.box(Vector3(x,.98,1.18),Vector3(.48,.044,.03),plaster)
		s.box(Vector3(x,.70,1.16),Vector3(.67,.085,.24),Color("#b39977"))
	s.box(Vector3(0,.08,1.33),Vector3(.92,.16,.49),Color("#bbb5a6"))
	s.box(Vector3(.64,2.60,-.71),Vector3(.37,1.09,.39),Color("#a7927b"))
	s.box(Vector3(.64,3.13,-.71),Vector3(.49,.18,.50),Color("#c6b8a3"))
	s.box(Vector3(.64,3.226,-.71),Vector3(.28,.016,.27),Color("#615549"))
	for row in 4:
		s.box(Vector3(.64,2.29+row*.20,-.507),Vector3(.33,.025,.014),Color("#c3af96"))
	s.blob(Vector3(0,1.94,1.073),Vector3(.37,.37,.055),Color("#c5a989"))
	s.blob(Vector3(0,1.94,1.103),Vector3(.25,.25,.036),Color("#93bfcc"))
	for j in 10:
		var x=-1.22+j*.265
		if absf(x)>.42:
			s.box(Vector3(x,.32+(j%3)*.045,1.078),Vector3(.19,.085,.030),Color("#d5c3a7"))

func furnace(s):
	s.rod(Vector3(0,.05,0),Vector3(0,1.16,0),.80,Color("#9c8b81"),.51,12)
	for row in 4:
		var n=12-row
		var rad=.67-row*.095
		for i in n:
			var a=TAU*(i+row*.45)/n
			if row<=1 and absf(wrapf(a-PI/2,-PI,PI))<.54:
				continue
			var col=Color(["#b8a492","#998b81","#b3a69b","#c2ac96"][(i+row)%4])
			s.box(Vector3(cos(a)*rad,.16+.27*row,sin(a)*rad),Vector3(.22,.25,rad*TAU/n+.025),col,Vector3(0,-a,0))
	s.rod(Vector3(0,1.04,0),Vector3(0,1.48,0),.34,Color("#b6a18b"),.74)
	s.rod(Vector3(0,1.46,0),Vector3(0,1.54,0),.30,Color("#c8b7a5"),1)
	s.rod(Vector3(0,1.535,0),Vector3(0,1.552,0),.19,Color("#514842"))
	s.blob(Vector3(0,.27,.661),Vector3(.76,.59,.25),Color("#6e4e39"))
	s.blob(Vector3(0,.22,.765),Vector3(.56,.43,.19),Color("#ef9143"))
	s.blob(Vector3(.03,.18,.845),Vector3(.32,.28,.11),Color("#ffda69"))

func bench(s):
	for x in [-.65,.65]:
		for z in [-.24,.24]:
			s.box(Vector3(x,.34,z),Vector3(.14,.68,.14),Color("#8b613f"))
	for j in 3:
		s.box(Vector3(0,.72,(j-1)*.247),Vector3(1.75,.13,.23),Color("#ce9c65").lightened(j*.025))
	s.box(Vector3(.34,.80,-.07),Vector3(.43,.07,.13),Color("#808995"),Vector3(0,-.24,0))
	s.rod(Vector3(-.44,.83,.13),Vector3(-.08,.83,.07),.043,Color("#916541"))

func crate(s):
	s.box(Vector3(0,.41,0),Vector3(.82,.82,.81),Color("#c69762"))
	for x in [-.38,.38]:
		s.box(Vector3(x,.41,.408),Vector3(.085,.82,.076),Color("#916b48"))
	for y in [.065,.76]:
		s.box(Vector3(0,y,.415),Vector3(.85,.10,.09),Color("#966f4c"))
		s.box(Vector3(.413,y,0),Vector3(.075,.10,.8),Color("#a98053"))
	s.box(Vector3(0,.41,.447),Vector3(.09,.98,.052),Color("#9b714b"),Vector3(0,0,-.76))
	s.box(Vector3(0,.824,0),Vector3(.87,.04,.77),Color("#dfb67d"))

func barrel(s):
	s.rod(Vector3(0,.02,0),Vector3(0,.41,0),.335,Color("#ba884c"),1.12,12)
	s.rod(Vector3(0,.41,0),Vector3(0,.84,0),.375,Color("#c6975b"),.90,12)
	for y in [.19,.65]:
		s.rod(Vector3(0,y-.043,0),Vector3(0,y+.043,0),.366,Color("#777781"),1,12)
	s.rod(Vector3(0,.839,0),Vector3(0,.85,0),.29,Color("#d8ad73"),1,12)

func logs(s):
	for p in [Vector2(-.33,.22),Vector2(.08,.22),Vector2(.48,.22),Vector2(-.12,.54),Vector2(.28,.54),Vector2(.07,.84)]:
		var a=Vector3(p.x,p.y,-.8)
		var b=Vector3(p.x,p.y,.81+sin(p.x*14)*.10)
		s.rod(a,b,.205,Color("#90603f"),1,10)
		s.rod(b,b+Vector3(0,0,.02),.166,Color("#d7aa72"),1,10)
		s.rod(b+Vector3(0,0,.02),b+Vector3(0,0,.027),.091,Color("#af7f50"),1,9)

func stump(s):
	s.rod(Vector3.ZERO,Vector3(0,.45,0),.44,Color("#8a5d40"),.85,10)
	s.rod(Vector3(0,.449,0),Vector3(0,.475,0),.35,Color("#dbad76"),1,10)
	s.rod(Vector3(0,.474,0),Vector3(0,.48,0),.20,Color("#ba925f"),1,10)
	s.box(Vector3(.06,.58,-.06),Vector3(.27,.16,.09),Color("#8a929b"),Vector3(0,0,.3))
	s.rod(Vector3(.12,.61,-.06),Vector3(.43,.86,-.06),.045,Color("#8d6547"))

func fence(s):
	for x in [-1.1,1.1]:
		s.box(Vector3(x,.33,0),Vector3(.14,.66,.15),Color("#bd945f"))
		s.blob(Vector3(x,.67,0),Vector3(.16,.11,.17),Color("#d5ad72"))
	for y in [.27,.47]:
		s.box(Vector3(0,y,0),Vector3(2.20,.105,.085),Color("#d7b781"))

func signpost(s):
	s.box(Vector3(0,.4,0),Vector3(.13,.8,.14),Color("#9b714b"))
	s.box(Vector3(0,.73,0),Vector3(.85,.28,.10),Color("#d3a875"))
	s.box(Vector3(-.04,.73,.06),Vector3(.45,.035,.02),Color("#866441"))

func cart(s):
	for x in [-.51,.51]:
		for z in [-.38,.38]:
			s.rod(Vector3(x-.035,.20,z),Vector3(x+.035,.20,z),.19,Color("#666474"),1,10)
	s.box(Vector3(0,.42,0),Vector3(1.04,.18,1.13),Color("#926949"))
	for x in [-.48,.48]:
		s.box(Vector3(x,.65,0),Vector3(.11,.46,1.12),Color("#bb8b58"))
	for z in [-.51,.51]:
		s.box(Vector3(0,.65,z),Vector3(.98,.45,.10),Color("#bb915f"))
	for i in 4:
		s.stone(Vector3(sin(i*5)*.28,.53,cos(i*3)*.29),Vector3(.36,.40,.35),Color("#a9a0a4"),i)

func market(s):
	s.box(Vector3(0,.42,.12),Vector3(2.36,.83,1.52),Color("#aa744e"))
	for i in 11:
		s.box(Vector3(-1.04+i*.207,.47,.90),Vector3(.19,.62,.055),Color("#c79662").darkened((i%3)*.022))
	s.box(Vector3(0,.89,.08),Vector3(2.52,.14,1.68),Color("#d7a873"))
	for x in [-1.13,1.13]:
		for z in [-.64,.67]:
			s.box(Vector3(x,1.19,z),Vector3(.105,2.38,.105),Color("#855f42"))
	for i in 9:
		var col=Color("#d75153" if i%2==0 else "#fff2d7")
		var x=-1.19+i*.297
		for side in [-1,1]:
			s.box(Vector3(x,2.41,side*.45),Vector3(.301,.09,1.03),col,Vector3(side*.24,0,0))
		s.box(Vector3(x,2.20,.955),Vector3(.301,.23,.084),col)
		s.blob(Vector3(x,2.09,.953),Vector3(.299,.15,.09),col)
	for i in 6:
		s.blob(Vector3(-.82+i*.137,1.03,.47+(i%2)*.10),Vector3(.17,.175,.17),Color("#be5940"))
	for i in 3:
		s.box(Vector3(.48+i*.13,1.04,.42),Vector3(.18,.19,.26),Color("#dcc789"))

func forge(s):
	s.rod(Vector3(-.48,0,0),Vector3(-.48,.72,0),.48,Color("#896449"),.86)
	s.box(Vector3(-.45,.84,0),Vector3(.99,.28,.51),Color("#737880"))
	s.rod(Vector3(.03,.87,0),Vector3(.42,.87,0),.16,Color("#a1a4aa"),.05,6)
	s.box(Vector3(.79,.55,-.28),Vector3(.83,1.1,.8),Color("#bcac9e"))
	s.box(Vector3(.79,1.38,-.28),Vector3(.61,.77,.6),Color("#aa9b8b"))
	s.box(Vector3(.79,1.85,-.28),Vector3(.47,.39,.46),Color("#c6b7a5"))
	s.blob(Vector3(.79,.38,.13),Vector3(.44,.37,.09),Color("#f9aa50"))

func cave(s):
	s.blob(Vector3(0,.68,0),Vector3(2.36,1.75,1.65),Color("#847a77"))
	s.box(Vector3(0,.58,.74),Vector3(.82,1.15,.14),Color("#3f414e"))
	for x in [-.56,.56]:
		s.box(Vector3(x,.62,.81),Vector3(.17,1.25,.2),Color("#9b704a"))
	s.box(Vector3(0,1.25,.8),Vector3(1.38,.21,.25),Color("#ba895b"))
	for i in 5:
		s.stone(Vector3(sin(i*2)*.85,0,cos(i*2)*.57),Vector3(.61,.70,.65),Color("#9a908b"),i)

func pillar(s,r):
	var h=r.randf_range(.9,1.5)
	s.box(Vector3(0,.10,0),Vector3(.90,.20,.85),Color("#b1ac95"))
	s.box(Vector3(0,h*.5+.1,0),Vector3(.63,h,.60),Color("#d0c8b0"),Vector3(0,0,.035))
	s.box(Vector3(.02,h+.1,0),Vector3(.69,.09,.63),Color("#c4c6a8"))
	s.blob(Vector3(-.12,h+.15,.08),Vector3(.37,.07,.23),Color("#8eac68"))
	s.box(Vector3(0,h*.56,.315),Vector3(.31,.04,.012),Color("#9d9b8f"),Vector3(0,0,.22))

func arch(s):
	for x in [-.91,.91]:
		for j in 4:
			s.box(Vector3(x, .28+j*.5,0),Vector3(.53,.48,.6),Color("#c8bfac").darkened(.022*(j%2)))
	for i in 7:
		var a=PI*i/6
		s.box(Vector3(cos(a)*.91,1.90+sin(a)*.62,0),Vector3(.49,.46,.64),Color("#cac4ae"),Vector3(0,0,a))

func chest(s,opened):
	s.box(Vector3(0,.28,0),Vector3(.95,.53,.65),Color("#b57f45"))
	s.box(Vector3(0,.55 if not opened else .78,-.05 if not opened else -.30),Vector3(.97,.27,.67),Color("#d5a462"),Vector3(-.78 if opened else 0.,0,0))
	for x in [-.32,.32]:
		s.box(Vector3(x,.33,.015),Vector3(.09,.63,.68),Color("#8b7c68"))
	s.box(Vector3(0,.38,.36),Vector3(.16,.17,.08),Color("#ebc960"))

func lily(s):
	s.blob(Vector3(0,.027,0),Vector3(.52,.045,.45),Color("#588e61"))
	for i in 5:
		var a=TAU*i/5
		s.blob(Vector3(.1+cos(a)*.067,.079,sin(a)*.067),Vector3(.108,.073,.095),Color("#f6c7d4"))
	s.blob(Vector3(.10,.116,0),Vector3(.065,.048,.065),Color("#f5d472"))

func ground_detail(s,kind,rand):
	if kind=="pebbles":
		for i in 4:
			s.stone(Vector3(rand.randf_range(-.20,.20),0,rand.randf_range(-.14,.15)),Vector3(.2,.12,.19)*rand.randf_range(.5,1.2),Color("#b4a8a0"),i)
	elif kind=="mushrooms":
		for i in 3:
			var a=TAU*i/3
			var p=Vector3(cos(a)*.13,0,sin(a)*.11)
			var h=.16+i*.025
			s.rod(p,p+Vector3.UP*h,.045,Color("#ead7b3"))
			s.blob(p+Vector3.UP*h,Vector3(.26,.19,.24),Color("#ca5044"))
			for j in 3:
				s.blob(p+Vector3(cos(j*2)*.065,h+.073,sin(j*2)*.05),Vector3(.052,.023,.044),Color("#fff0ca"))
	elif kind=="flowers" or kind=="yellow":
		for j in 3:
			var p=Vector3(rand.randf_range(-.24,.24),.10+j*.026,rand.randf_range(-.21,.21))
			s.rod(Vector3(p.x,0,p.z),p,.018,Color("#6c9745"),.55,4)
			for i in 5:
				var a=TAU*i/5
				s.blob(p+Vector3(cos(a)*.063,0,sin(a)*.063),Vector3(.115,.048,.108),Color("#fff2d0" if kind=="flowers" else "#f6cc68"))
			s.blob(p+Vector3.UP*.025,Vector3(.065,.038,.065),Color("#dfae41"))
	else:
		for i in (8 if kind=="fern" else 5):
			var a=TAU*i/5+rand.randf_range(-.24,.24)
			var tip=Vector3(cos(a)*rand.randf_range(.09,.22),rand.randf_range(.13,.30),sin(a)*.18)
			var side=Vector3(-sin(a)*.047,0,cos(a)*.047)
			s.tri(-side,side,tip,Color("#669844").lightened(i*.018),Vector3.UP)

func soil(s):
	s.box(Vector3(0,.026,0),Vector3(1.21,.055,1.21),Color("#926343"))
	for i in 7:
		s.blob(Vector3(sin(i*5.2)*.33,.055,cos(i*7.3)*.41),Vector3(.29,.037,.13),Color("#a17551"))

func crop(s,kind):
	if kind=="carrot":
		s.rod(Vector3.ZERO,Vector3(0,.28,0),.05,Color("#e7863f"),3.7)
		s.blob(Vector3(0,.27,0),Vector3(.39,.2,.36),Color("#f29943"))
	elif kind=="turnip":
		s.blob(Vector3(0,.17,0),Vector3(.58,.41,.55),Color("#cba8cf"))
	else:
		s.blob(Vector3(0,.22,0),Vector3(.62,.45,.61),Color("#9ac36e"))
	for i in 7:
		var a=TAU*i/7
		var p=Vector3(cos(a)*.12,.33 if kind!="cabbage" else .20,sin(a)*.12)
		s.blob(p,Vector3(.15 if kind!="cabbage" else .29,.41 if kind!="cabbage" else .30,.13 if kind!="cabbage" else .28),
				Color("#79ab58" if kind!="cabbage" else "#a8cd83").lightened(i*.014),Vector3(sin(a)*.58,0,-cos(a)*.58))

func scarecrow(s):
	s.rod(Vector3.ZERO,Vector3(0,1.53,0),.06,Color("#98774c"))
	s.box(Vector3(0,1.04,0),Vector3(.94,.1,.1),Color("#bd9962"))
	s.blob(Vector3(0,1.02,0),Vector3(.35,.58,.27),Color("#71aabe"))
	s.blob(Vector3(0,1.43,0),Vector3(.38,.37,.35),Color("#e3bc7e"))
	s.rod(Vector3(0,1.57,0),Vector3(0,1.64,0),.38,Color("#e7bd6e"))
	s.blob(Vector3(0,1.68,0),Vector3(.5,.29,.47),Color("#e5be79"))
