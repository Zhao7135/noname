extends RefCounted

static var ground_mat: StandardMaterial3D
static var cliff_mat: StandardMaterial3D
static var water_mat: ShaderMaterial

static func footprint(w: float, h: float, id: int) -> PackedVector2Array:
	var offset := .12 * sin(id*4.1)
	var corners := PackedVector2Array([
		Vector2(-.50,-.33),Vector2(-.10+offset,-.33),Vector2(-.10+offset,-.50),
		Vector2(.40,-.50),Vector2(.40,-.34),Vector2(.50,-.34),
		Vector2(.50,.30),Vector2(.32+offset,.30),Vector2(.32+offset,.50),
		Vector2(-.34,.50),Vector2(-.34,.39),Vector2(-.50,.39)])
	for i in corners.size():
		corners[i] *= Vector2(w,h)
	return round_poly(corners,.48 if id==0 else .36)

static func round_poly(corners: PackedVector2Array, radius: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in corners.size():
		var p:=corners[i]
		var a:=p+p.direction_to(corners[posmod(i-1,corners.size())])*radius
		var b:=p+p.direction_to(corners[(i+1)%corners.size()])*radius
		for j in 5:
			var t:=j/4.0
			poly.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
	return poly

static func material(tex, vertex := false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_texture=tex
	m.vertex_color_use_as_albedo=vertex
	m.vertex_color_is_srgb=true
	m.roughness=1.0
	m.metallic_specular=.07
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

static func ground_mesh(poly: PackedVector2Array, id: int) -> ArrayMesh:
	if not ground_mat:
		ground_mat=material(preload("res://art/grass.jpg"),true)
		cliff_mat=material(preload("res://art/cliff.jpg"),true)
	var mesh:=ArrayMesh.new()
	var tri:=Geometry2D.triangulate_polygon(poly)
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(ground_mat)
	var tint=Color.WHITE if id==0 else Color("#f2f8e9").lightened(float(id%4)*.07)
	for i in range(0,tri.size(),3):
		for j in 3:
			var p=poly[tri[i+j]]
			st.set_color(tint)
			st.set_normal(Vector3.UP)
			st.set_uv(p*.16)
			st.add_vertex(Vector3(p.x,0,p.y))
	st.commit(mesh)
	var rings = [[0.,0.], [.09,-.06], [.13,-.18], [.10,-.31], [.025,-.38]]
	side(mesh,poly,rings,ground_mat,true)
	side(mesh,poly,[[.025,-.37],[.01,-.9],[-.09,-2.6],[-.24,-3.26]],cliff_mat,false)
	return mesh

static func side(mesh,poly,rings,mat,is_turf):
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var u:=0.0
	for i in poly.size():
		var a: Vector2=poly[i]
		var b: Vector2=poly[(i+1)%poly.size()]
		var next_u=u+a.distance_to(b)
		var tang=(b-a).normalized()
		var outward=Vector3(tang.y,0,-tang.x)
		for row in rings.size()-1:
			for index in [0,1,2,0,2,3]:
				var far_end=index==2 or index==3
				var lower=index==1 or index==2
				var ring=rings[row+int(lower)]
				var point: Vector2=b if far_end else a
				var p3=Vector3(point.x,ring[1],point.y)
				p3+=Vector3(point.x,0,point.y).normalized()*float(ring[0])
				var normal=outward
				if is_turf:
					normal=(outward+Vector3.UP*maxf(0,2.2-(row+int(lower))*.85)).normalized()
					st.set_color(Color.WHITE.darkened((row+int(lower))*.033))
				else:
					st.set_color(Color.WHITE.lerp(Color("#b7acd4"),clampf((-p3.y-1.55)*.26,0,.50)))
				st.set_normal(normal)
				st.set_uv(Vector2((next_u if far_end else u)*(.12 if is_turf else .16),-p3.y*(.24 if is_turf else .40)))
				st.add_vertex(p3)
		u=next_u
	st.commit(mesh)

static func flat(poly: PackedVector2Array, y: float, mat: Material) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for i in Geometry2D.triangulate_polygon(poly):
		var p:=poly[i]
		st.set_normal(Vector3.UP)
		st.set_uv(p)
		st.add_vertex(Vector3(p.x,y,p.y))
	return st.commit()

static func water() -> ShaderMaterial:
	if water_mat:
		return water_mat
	water_mat=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment(){
 vec2 p=UV; float t=TIME;
 float a=sin(p.x*8.7+p.y*4.5+t*1.25+sin(p.y*6.2-t));
 float b=sin(p.y*13.0-p.x*4.3-t*1.1+sin(p.x*8.0+t*.7));
 float glint=smoothstep(1.63,1.93,a+b);
 float rip=sin(p.x*2.7+p.y*3.2+t)*.5+.5;
 vec3 pool=mix(vec3(.19,.66,.84),vec3(.32,.80,.91),rip*.55);
 ALBEDO=mix(pool,vec3(.85,.97,1.),glint*.63); ROUGHNESS=.4;
}"""
	water_mat.shader=shader
	return water_mat
