extends RefCounted

# All components of a miniature share one vertex-coloured surface.
static var primitives: Dictionary = {}
static var paint: StandardMaterial3D
var points := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static func material() -> StandardMaterial3D:
	if not paint:
		paint = StandardMaterial3D.new()
		paint.vertex_color_use_as_albedo = true
		paint.vertex_color_is_srgb = true
		paint.roughness = 0.94
		paint.metallic_specular = 0.22
	return paint

func geometry(key: String, mesh: PrimitiveMesh) -> Array:
	if not primitives.has(key):
		primitives[key] = mesh.get_mesh_arrays()
	return primitives[key]

func append(data: Array, pos: Vector3, basis: Basis, color: Color) -> void:
	var src: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var start := points.size()
	var normal_basis := basis.inverse().transposed()
	for i in src.size():
		points.append(pos + basis * src[i])
		normals.append((normal_basis * ns[i]).normalized())
		colors.append(color)
	for idx in index:
		indices.append(start + idx)

func box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var data: Array
	if primitives.has("box"):
		data = primitives.box
	else:
		data = geometry("box", BoxMesh.new())
	append(data, pos, Basis.from_euler(rot) * Basis.from_scale(size), col)

func blob(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var data: Array
	if primitives.has("round"):
		data = primitives.round
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 14
		sphere.rings = 7
		data = geometry("round",sphere)
	append(data,pos,Basis.from_euler(rot)*Basis.from_scale(size),col)

func rod(a: Vector3, b: Vector3, radius: float, color: Color, taper := 1.0, sides := 9) -> void:
	var key := "%d-%d" % [sides,roundi(taper*100)]
	var data: Array
	if primitives.has(key):
		data = primitives[key]
	else:
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 1
		cylinder.top_radius = taper
		cylinder.height = 1
		cylinder.radial_segments = sides
		cylinder.rings = 0
		data = geometry(key,cylinder)
	var length := a.distance_to(b)
	if length < 0.0001:
		return
	var basis := Basis(Quaternion(Vector3.UP,(b-a)/length))
	append(data,(a+b)*0.5,basis*Basis.from_scale(Vector3(radius,length,radius)),color)

func tri(a: Vector3,b: Vector3,c: Vector3,col: Color,face_out: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	var start := points.size()
	points.append_array(PackedVector3Array([a,b,c]))
	if normal.dot(face_out) < 0:
		normal = -normal
		indices.append_array(PackedInt32Array([start,start+2,start+1]))
	else:
		indices.append_array(PackedInt32Array([start,start+1,start+2]))
	for i in 3:
		normals.append(normal)
		colors.append(col)

# Unequal stone rings produce chipped planes with a readable silhouette.
func stone(base: Vector3,size: Vector3,col: Color,seed_value: int) -> void:
	var start:=points.size()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + 42797
	var rings := []
	var sides := 7
	var phase := random.randf()*TAU
	for j in 3:
		var ring := PackedVector3Array()
		for i in sides:
			var angle := TAU*i/sides + phase + (0.10 if j == 2 else 0.0)
			var rad := random.randf_range(.87,1.13) * [0.47,0.50,0.27][j] as float
			ring.append(base + Vector3(cos(angle)*rad*size.x,([.015,.48,.88][j]+random.randf_range(-.06,.06))*size.y,sin(angle)*rad*size.z))
		rings.append(ring)
	var cap := base+Vector3(.07*size.x,size.y,-.03*size.z)
	for i in sides:
		var k := (i+1)%sides
		var out: Vector3 = (rings[1][i]-base)*Vector3(1,0,1)
		for j in 2:
			var tint := col.darkened(random.randf_range(0,.075))
			tri(rings[j][i],rings[j][k],rings[j+1][k],tint,out)
			tri(rings[j][i],rings[j+1][k],rings[j+1][i],tint,out)
		tri(rings[2][i],rings[2][k],cap,col,Vector3.UP)
	for i in range(start,points.size()):
		var outward=((points[i]-base-Vector3.UP*size.y*.32)/size).normalized()
		normals[i]=normals[i].lerp(outward,.53).normalized()

func canopy(pos:Vector3,size:Vector3,col:Color,random:RandomNumberGenerator):
	var lobes:Array[Vector4]=[]
	for ring in 2:
		for i in (8 if ring==0 else 5):
			var a=TAU*i/(8. if ring==0 else 5.)+ring*.55
			var radius=.52 if ring==0 else .37
			lobes.append(Vector4(cos(a)*radius,(-.17 if ring==0 else .34)+random.randf_range(-.08,.08),sin(a)*radius,random.randf_range(.50,.64)))
	lobes.append(Vector4(-.10,.53,-.09,.53))
	var start=points.size()
	var slices=38
	var rings=22
	for j in range(rings+1):
		var v=PI*j/rings
		for i in range(slices+1):
			var u=TAU*i/slices
			var n=Vector3(sin(v)*cos(u),cos(v),sin(v)*sin(u))
			var extent=.86
			var normal=n
			for l in lobes:
				var c=Vector3(l.x,l.y,l.z)
				var dot=n.dot(c)
				var disc=l.w*l.w-c.length_squared()+dot*dot
				if disc<=0:
					continue
				var reach=dot+sqrt(disc)
				var blend=clampf(.5+.5*(reach-extent)/.095,0.,1.)
				var sphere_normal=(n*reach-c).normalized()
				normal=normal.lerp(sphere_normal,blend).normalized()
				extent=lerpf(extent,reach,blend)+.095*blend*(1.-blend)
			points.append(pos+n*extent*size)
			normals.append((normal/size).normalized())
			var tint=.034*sin(n.x*19+n.z*8)*sin(n.y*13-n.z*9)+.020*cos(n.z*28+n.y*19)+.055*n.y
			colors.append(col.lightened(maxf(0,tint)).darkened(maxf(0,-tint)))
	for j in rings:
		for i in slices:
			var a=start+j*(slices+1)+i
			var b=a+slices+1
			if j>0:
				indices.append_array(PackedInt32Array([a,b,a+1]))
			if j<rings-1:
				indices.append_array(PackedInt32Array([a+1,b,b+1]))

func mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=points
	arr[Mesh.ARRAY_NORMAL]=normals
	arr[Mesh.ARRAY_COLOR]=colors
	arr[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	result.surface_set_material(0,material())
	return result
