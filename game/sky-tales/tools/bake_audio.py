"""Compose the 48-second loop and bake event sounds from oscillators and filtered noise."""
from pathlib import Path
import wave
import numpy as np

OUT=Path(__file__).resolve().parents[1]/"sound"
OUT.mkdir(exist_ok=True)
SR=32000
rng=np.random.default_rng(1908)


def write(name,samples):
    samples=np.asarray(samples)
    with wave.open(str(OUT/(name+".wav")),"wb") as f:
        f.setparams((1 if samples.ndim==1 else 2,2,SR,0,"NONE","not compressed"))
        f.writeframes((np.clip(samples,-.98,.98)*32767).astype("<i2").tobytes())


def note(key,length,kind):
    t=np.arange(int(SR*length))/SR
    freq=440*2**((key-69)/12)
    phase=2*np.pi*freq*t
    if kind=="bass":
        result=(np.sin(phase)+.24*np.sin(phase*2)+.09*np.sin(phase*3))*np.exp(-t*3.0)
        attack=.016
    elif kind=="felt":
        result=(np.sin(phase)+.38*np.sin(2.001*phase)*np.exp(-t*2.2)
                +.15*np.sin(3.007*phase)*np.exp(-t*4.5)+.08*np.sin(4.006*phase))*np.exp(-t*2.3)
        attack=.009
    elif kind=="string":
        result=sum(np.sin(phase*n)*np.exp(-t*(3.1+n*.8))/(n**1.48) for n in range(1,7))
        attack=.006
    else:
        result=(np.sin(phase)+.28*np.sin(phase*2.003)*np.exp(-t*4)+.12*np.sin(phase*3.98)*np.exp(-t*6))*np.exp(-t*3.3)
        attack=.005
    return result*np.minimum(1,t/attack)*np.minimum(1,(length-t)/.065)


duration=48; music=np.zeros((duration*SR,2))
def place(start,data,volume,pan=0):
    idx=(int(start*SR)+np.arange(len(data)))%len(music)
    music[idx,0]+=data*volume*np.sqrt((1-pan)/2)
    music[idx,1]+=data*volume*np.sqrt((1+pan)/2)

voicings={"C":(48,[60,64,67,71]),"Am":(45,[57,60,64,67]),"F":(41,[57,60,65,69]),
          "G":(43,[55,59,62,67]),"Dm":(50,[57,62,65,69])}
form=["C","Am","F","G","C","Am","F","G","Am","F","C","G","Am","F","Dm","G"]
phrases=[
    [76,None,79,83,81,None,79,None],[76,None,72,76,None,79,76,None],
    [77,None,81,79,77,None,76,None],[74,71,None,74,79,None,None,None],
    [72,None,76,79,83,None,79,76],[81,None,79,76,72,None,76,None],
    [77,None,76,72,69,None,72,None],[74,None,71,67,71,None,None,None],
    [76,79,None,81,84,None,83,81],[77,None,81,None,79,77,76,None],
    [79,None,76,72,76,None,79,None],[83,None,81,79,74,None,71,None],
    [81,None,76,72,76,None,79,None],[77,None,81,84,81,None,77,None],
    [77,76,74,None,69,None,74,None],[71,None,74,79,74,None,71,None]]
for bar,chord in enumerate(form):
    start=bar*3; root,tones=voicings[chord]
    for off,b in [(0,root),(1.5,root+7)]:
        place(start+off,note(b,1.4,"bass"),.22,-.06)
    for j,idx in enumerate([0,1,2,1,0,2,3,2]):
        place(start+j*.375+.012,note(tones[idx],.92,"string"),.071+.009*(j%3),-.35)
    for beat in [0,1.5]:
        for j,m in enumerate(tones[:3]):
            place(start+beat+j*.019,note(m,1.8,"felt"),.065,.22)
    for j,m in enumerate(phrases[bar]):
        if m is not None:
            place(start+j*.375,note(m,1.35,"bell"),.12*(1-.13*(j%2)),.12)
    for beat in [0,.75,1.5,2.25]:
        t=np.arange(int(SR*.095))/SR
        noise=rng.normal(0,1,len(t)); brush=np.diff(noise,prepend=0)*np.exp(-t*64)
        place(start+beat+.373,brush,.008,.4)
dry=music.copy()
for lag,vol in [(.105,.10),(.183,.085),(.307,.045)]:
    music+=np.roll(dry[:,::-1],int(SR*lag),axis=0)*vol
write("cloud_garden",music*.77/np.max(abs(music)))


def effect(name,dur,base=0,tail=6,noise=0,metal=(),glide=0):
    t=np.arange(int(SR*dur))/SR
    env=np.exp(-t*tail)*np.minimum(1,t/.0025)*np.minimum(1,(dur-t)/.025)
    rnd=rng.normal(0,1,len(t)); rnd=np.convolve(rnd,np.ones(5)/5,"same")
    sig=noise*rnd*np.exp(-t*11)
    if base:
        phase=2*np.pi*(base*t+.5*glide*t*t)
        sig+=np.sin(phase)+.25*np.sin(2*phase)
    for freq,vol in metal: sig+=vol*np.sin(2*np.pi*freq*t)*np.exp(-t*3)
    wav=sig*env
    write(name,.72*wav/max(.001,np.max(abs(wav))))

effect("step",.13,67,34,.72,glide=-160)
effect("timber",.28,148,19,.65,[(360,.55),(603,.19)],-200)
effect("rock",.30,245,18,1.1,[(1270,.63),(1850,.28),(3200,.14)],-230)
effect("ore",.42,570,13,.8,[(1515,.63),(2320,.35),(3680,.11)])
effect("leaves",.29,0,12,1)
effect("pickup",.18,620,15,.05,[(1250,.13)],2100)
effect("tap",.10,440,26,.12,[(1090,.18)],260)
effect("no",.20,182,13,.12,glide=-165)
effect("fire",.50,79,8,1.9,[(165,.15)],-40)
effect("soil",.22,88,21,1.1,glide=-70)
effect("eat",.20,210,15,.85,glide=510)
effect("plank",.19,195,18,.66,[(520,.41)],-240)
effect("water",.65,510,7,.25,[(1110,.17)],-445)
def chime(name,keys,step,kind="bell"):
    data=np.zeros(int((len(keys)*step+.88)*SR))
    for i,k in enumerate(keys):
        sound=note(k,.85,kind)*(.72 if i==len(keys)-1 else .55)
        offset=int(i*step*SR); data[offset:offset+len(sound)]+=sound
    write(name,data*.82/max(np.max(abs(data)),.4))
chime("sell",[79,86,91],.075)
chime("ready",[72,79],.13)
chime("build",[60,67,72],.10,"string")
chime("level",[72,76,79,83,84],.095)
chime("island",[60,64,67,72,76,79],.145,"felt")
chime("treasure",[72,79,84,88,91],.13)
