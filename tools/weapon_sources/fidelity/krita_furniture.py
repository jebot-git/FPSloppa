"""Krita MCP: layered furniture surface refinement, preserving existing documents."""
from PyQt6.QtGui import QImage,QColor,QPainter,QPen
from PyQt6.QtCore import Qt,QByteArray
from pathlib import Path
import random,math
root=Path('/home/blux/Documents/FPSloppa/tools/weapon_sources/fidelity');base=QImage(str(root/'realistic-surfaces.png')).convertToFormat(QImage.Format.Format_ARGB32);rng=random.Random(812)
for y in range(512):
 for x in range(1024):
  tile=(1-y//256)*4+x//256;c=base.pixelColor(x,y);rgb=[c.red(),c.green(),c.blue()]
  if tile==2:rgb=[max(0,(v-70)*1.35+70)*f for v,f in zip(rgb,[1.10,.91,.72])]
  elif tile==1:
   grain=rng.uniform(-4,4)+(2 if ((x//3+y//3)%2)==0 else -1)
   rgb=[max(0,v*.84+grain) for v in rgb]
  elif tile==4:rgb=[v*.76+rng.uniform(-1.5,1.5) for v in rgb]
  elif tile==5:rgb=[v*.75 for v in rgb]
  else:rgb=[v+rng.uniform(-1.4,1.4) for v in rgb]
  base.setPixelColor(x,y,QColor(*[min(255,max(0,int(v))) for v in rgb]))
wear=QImage(1024,512,QImage.Format.Format_ARGB32);wear.fill(Qt.GlobalColor.transparent);p=QPainter(wear)
for tile in [0,4,5]:
 ox=tile%4*256;oy=(1-tile//4)*256
 for i in range(60):
  x=ox+rng.randrange(12,239);y=oy+rng.randrange(12,243);p.setPen(QPen(QColor(150,151,144,18),1));p.drawLine(x,y,x+rng.randrange(2,7),y)
p.end()
d=Krita.instance().createDocument(1024,512,'ST and CS contoured furniture surfaces','RGBA','U8','',72);d.setBatchmode(True)
for name,img in [('Walnut grain and molded polymer',base),('Fine handling wear',wear)]:
 layer=d.createNode(name,'paintlayer');d.rootNode().addChildNode(layer,None);bits=img.bits();bits.setsize(img.sizeInBytes());layer.setPixelData(QByteArray(bytes(bits)),0,0,1024,512)
d.refreshProjection();d.waitForDone();d.setFileName(str(root/'furniture-surfaces.kra'));d.save();d.projection(0,0,1024,512).save(str(root/'furniture-surfaces.png'));Krita.instance().activeWindow().addView(d)
result={'file':d.fileName(),'layers':[n.name() for n in d.rootNode().childNodes()]}
