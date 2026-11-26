"""Bake the island materials and hand-drawn inventory icons. Requires Pillow and NumPy."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "art"
OUT.mkdir(exist_ok=True)
(OUT / "icons").mkdir(exist_ok=True)
rng = np.random.default_rng(2428)


def field(w, h, grid):
    gy = max(2, round(grid * h / w))
    values = rng.random((gy, grid))
    y, x = np.mgrid[:h, :w]
    x, y = x * grid / w, y * gy / h
    ix, iy = x.astype(int), y.astype(int)
    fx, fy = x % 1, y % 1
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = values[iy % gy, ix % grid] * (1 - fx) + values[iy % gy, (ix + 1) % grid] * fx
    b = values[(iy + 1) % gy, ix % grid] * (1 - fx) + values[(iy + 1) % gy, (ix + 1) % grid] * fx
    return a * (1 - fy) + b * fy


def rgb_file(name, values):
    Image.fromarray(np.clip(values, 0, 255).astype('uint8')).save(OUT / name)


w = h = 384
n = (field(w,h,5)-.5)*.12 + (field(w,h,19)-.5)*.09 + (field(w,h,76)-.5)*.05 + rng.normal(0,.012,(h,w))
rgb_file("grass.jpg", np.array([164,193,88])[None,None,:] * (1+n[:,:,None]) + n[:,:,None]*[48,25,-38])

w, h = 768, 384
y, x = np.mgrid[:h, :w]
sx = x/w*14 + (field(w,h,10)-.5)*.23
sy = y/h*10 + (field(w,h,12)-.5)*.22
cx, cy = np.floor(sx).astype(int), np.floor(sy).astype(int)
near = np.full((h,w),50.0); second = near.copy(); ids = np.zeros((h,w),int)
sites = rng.random((10,14,2))*.85+.075
for dy in (-1,0,1):
    for dx in (-1,0,1):
        col, row = (cx+dx)%14,(cy+dy)%10
        p = sites[row,col]
        dist = (cx+dx+p[:,:,0]-sx)**2 + (cy+dy+p[:,:,1]-sy)**2
        mask = dist<near
        second = np.where(mask,near,np.minimum(second,dist))
        near = np.minimum(near,dist)
        ids = np.where(mask,row*14+col,ids)
colors = np.array([[148,106,78],[164,118,85],[151,106,78],[124,88,72],
                   [143,100,83],[170,130,102],[137,100,85],[153,114,90],[170,142,129]])
palette = colors[rng.choice(len(colors),140,p=[.2,.15,.15,.10,.12,.1,.08,.07,.03])]
grout = np.clip((second-near)*8,0,1)
rgb_file("cliff.jpg",palette[ids] * (.93 + .07*grout[:,:,None]) + ((field(w,h,56)-.5)*7)[:,:,None])


def cloud(index):
    w,h=520,290
    yy,xx=np.mgrid[:h,:w]
    xx=(xx-w/2)/(w/2); yy=(h*.52-yy)/(h*.50)
    fine = field(w,h,48)-.5
    grain = (field(w,h,11)-.5)*.075 + (field(w,h,24)-.5)*.035 + fine*.014
    depth=np.full((h,w),-2.0)
    balls=[(-.57,-.04,.32,.36),(-.29,.03,.38,.53),(.01,.12,.38,.65),
           (.30,.03,.35,.49),(.56,-.08,.34,.36),(-.10,-.18,.56,.35)]
    for i in range(27):
        bx=rng.uniform(-.73,.73)
        balls.append((bx,rng.uniform(-.26,.29)*(1-abs(bx)*.65),rng.uniform(.12,.26),rng.uniform(.17,.39)))
    for bx,by,rx,ry in balls:
        bx+=rng.uniform(-.04,.04); by+=rng.uniform(-.06,.06)
        q=1-((xx-bx)/rx)**2-((yy-by)/ry)**2 + grain*4
        z=np.where(q>=0,np.sqrt(np.maximum(q,0))*rx+.018, q*.19)
        depth=np.maximum(depth,z)
    gy,gx=np.gradient(depth+grain*.32)
    light=np.clip(.71-gx*24+gy*12+yy*.20+grain*.9,0,1)
    light=np.where(depth>0,light,.77)
    col=np.array([185,194,219])+light[:,:,None]*np.array([70,61,35])
    alpha=np.clip((depth+.009)*13,0,1)
    rgba=np.dstack((col,alpha*255)).clip(0,255).astype('uint8')
    Image.fromarray(rgba).filter(ImageFilter.GaussianBlur(.75)).save(OUT / f"cloud{index}.png")

for number in range(3):
    cloud(number)


def icon(name):
    img = Image.new("RGBA",(112,112))
    d = ImageDraw.Draw(img)
    def poly(pts,color,outline=None):
        d.polygon(pts,fill=color)
        if outline: d.line(pts+[pts[0]], fill=outline,width=3,joint="curve")
    def line(pts,fill,width=4): d.line(pts,fill,width,joint="curve")
    def ell(box,fill,outline=None): d.ellipse(box,fill,outline,width=3)
    def box(x,y,w,h,dep,top,face,side):
        poly([(x,y),(x+dep,y-dep*.6),(x+w+dep,y-dep*.32),(x+w,y+dep*.35)],top)
        poly([(x,y),(x+w,y+dep*.35),(x+w,y+h+dep*.35),(x,y+h)],face)
        poly([(x+w,y+dep*.35),(x+w+dep,y-dep*.32),(x+w+dep,y+h-dep*.32),(x+w,y+h+dep*.35)],side)
    if name in ("brick","iron","gold","wood"):
        t,f,s={"brick":("#ffad83","#c86d55","#a45748"),"wood":("#dea871","#bd8158","#895b46"),
               "iron":("#e5edfd","#a6bbd8","#7990ae"),"gold":("#fff298","#f7c444","#c18a29")}[name]
        if name=="wood": box(9,53,65,16,29,t,f,s)
        box(12,40,62,19,27,t,f,s)
        if name=="wood": line([(21,39),(65,48),(77,43)],"#ad734e",2)
    elif name in ("stone","iron_ore","gold_ore","crystal"):
        poly([(8,76),(16,48),(36,41),(49,19),(68,24),(77,45),(95,49),(102,74),(73,88),(31,88)],"#9b9aab")
        poly([(16,48),(36,41),(47,57),(29,76),(8,76)],"#bfc2cc")
        poly([(36,41),(49,19),(68,24),(71,46),(47,57)],"#dadee0")
        poly([(47,57),(71,46),(86,68),(73,88),(31,88)],"#88879a")
        if name!="stone":
            colors={"iron_ore":("#f4a269","#bc6543"),"gold_ore":("#ffdf60","#d99826"),"crystal":("#96f7fd","#4caed7")}[name]
            for ax,ay in [(34,53),(55,42),(73,58)]:
                poly([(ax-8,ay),(ax-6,ay-18),(ax+2,ay-24),(ax+9,ay-19),(ax+8,ay)],colors[0])
                poly([(ax+2,ay-16),(ax+9,ay-19),(ax+8,ay),(ax,ay+4)],colors[1])
    elif name=="berry":
        for x,y in [(35,56),(65,50),(54,73)]:
            ell((x-17,y-16,x+17,y+18),"#d34849","#943742");ell((x-10,y-9,x-3,y-3),"#ffafa0")
        poly([(54,45),(34,34),(29,15),(50,23),(61,37),(74,16),(81,13),(76,37)],"#669745")
    elif name in ("carrot","turnip","cabbage"):
        if name=="carrot": poly([(21,89),(32,52),(55,33),(75,43),(68,63)],"#ed9951","#a7683c")
        elif name=="turnip": ell((20,39,84,89),"#c4a0da","#93779d");ell((23,41,79,73),"#efdfdb")
        else:
            for x,y,c in [(30,52,"#769d50"),(48,40,"#88b654"),(67,53,"#9ec372"),(41,68,"#a5cb77")]:
                ell((x-19,y-17,x+18,y+18),c,"#72974d")
        if name!="cabbage": poly([(61,43),(49,22),(54,13),(67,32),(77,11),(82,15),(74,36),(94,23),(94,31)],"#69a24f")
    elif name in ("pick","power","craft","forge"):
        if name=="forge":
            box(13,65,63,22,19,"#8e98a2","#67707a","#47555e")
            line([(46,49),(78,20)],"#845f45",10)
        else: line([(26,90),(73,32)],"#6a4a36",13);line([(27,87),(71,33)],"#b07c4c",7)
        if name=="craft" or name=="forge": poly([(44,19),(62,9),(87,33),(69,49)],"#7e8d9c","#524f50")
        else: poly([(13,51),(25,31),(47,19),(68,19),(89,32),(98,55),(79,39),(64,33),(40,35)],"#afb5bd","#5f625f")
    elif name=="magnet":
        d.arc((20,18,92,88),180,360,fill="#ad4f50",width=17)
        for x in [20,75]:
            d.rectangle((x,49,x+16,78),fill="#da6967");d.rectangle((x,70,x+16,82),fill="#a6b3c5")
    elif name=="energy": poly([(61,7),(25,60),(48,60),(39,100),(88,42),(63,42),(75,7)],"#f9c83b","#815e2e")
    elif name=="luck":
        for x,y in [(39,36),(64,36),(40,60),(63,59)]: ell((x-14,y-14,x+14,y+14),"#8fca58","#568741")
        line([(54,55),(74,89)],"#678c46",6)
    elif name=="market":
        box(13,59,68,30,18,"#dca66f","#bb8655","#866144")
        for x in (18,80): line([(x,67),(x,33)],"#76563d",5)
        for k in range(7):
            x=12+12*k; poly([(x+4,24),(x+16,24),(x+11,48),(x-1,48)],"#d25154" if k%2==0 else "#ffefd4")
            d.rounded_rectangle((x-1,43,x+11,57),4,fill="#b33e46" if k%2==0 else "#e8d5b5")
    elif name=="furnace":
        poly([(15,84),(19,60),(33,43),(43,28),(45,16),(63,14),(68,36),(80,51),(90,84)],"#a49687","#766b63")
        for x,y in [(38,48),(64,42),(29,62),(70,66),(52,30)]: d.rounded_rectangle((x-8,y-3,x+8,y+4),2,fill="#c3b5a4")
        ell((37,60,67,89),"#6d5040");ell((43,71,63,90),"#ffc350");ell((49,76,59,89),"#fff0a5")
    elif name=="coin":
        ell((18,16,94,94),"#efb537","#b28038");ell((28,25,83,84),"#ffd665","#cf942c")
        poly([(55,34),(66,44),(63,65),(52,74),(44,63),(46,43)],"#e6a837")
    elif name=="island":
        poly([(8,45),(49,27),(103,44),(96,77),(60,98),(17,80)],"#9d7159","#695849")
        poly([(8,44),(48,27),(103,42),(96,54),(57,71),(15,58)],"#98bf6c","#6b8e4f")
        box(46,39,22,18,11,"#f7d4aa","#ffdfb6","#c7a181")
        poly([(41,42),(53,24),(71,24),(83,39),(67,44)],"#d97d48")
        for x,y in [(29,34),(80,35)]:
            d.rectangle((x-2,y,x+3,y+13),fill="#895b3d");ell((x-10,y-15,x+10,y+3),"#72a951")
    return img.resize((80,80),Image.Resampling.LANCZOS)

for name in ("wood","stone","berry","iron_ore","gold_ore","crystal","brick","iron","gold","carrot",
             "cabbage","turnip","furnace","market","forge","pick","power","craft","magnet","energy","luck","coin","island"):
    img=icon(name)
    img.save(OUT / ("island.png" if name=="island" else f"icons/{name}.png"))
    if name=="island":
        img.resize((256,256),Image.Resampling.LANCZOS).save(OUT / "island.ico",
            sizes=[(n,n) for n in (16,24,32,48,64,128,256)])
