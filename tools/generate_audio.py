import math, wave, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets/audio'
for name,notes in {'collect':[660,880,1100], 'fail':[220,175,110], 'win':[523,659,784,1047], 'turn':[180,140]}.items():
    data=[]
    for f in notes:
        n=6000
        for i in range(n):
            t=i/24000
            v=math.sin(2*math.pi*f*t)*0.22*(1-i/n)**2
            data.append(struct.pack('<h',int(v*32767)))
    with wave.open(str(root/(name+'.wav')),'wb') as w:
        w.setparams((1,2,24000,0,'NONE','not compressed'));w.writeframes(b''.join(data))
