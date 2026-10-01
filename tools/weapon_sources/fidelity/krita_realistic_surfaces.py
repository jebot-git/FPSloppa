"""Run in Krita MCP. Creates new editable material studies; preserves other docs."""
from PyQt6.QtGui import QImage,QPainter,QColor,QPen,QTransform
from PyQt6.QtCore import Qt,QByteArray
from pathlib import Path
import random,math
root=Path('/home/blux/Documents/FPSloppa/tools/weapon_sources/fidelity')
metal=QImage(str(root/'sources/polyhaven/metal_plate_02.jpg')).copy(520,40,210,190).scaled(256,256)
wood=QImage(str(root/'sources/polyhaven/fine_grained_wood.jpg')).transformed(QTransform().rotate(90)).scaled(256,256)
# Microvariation from the source photography, recolored to firearm finishes.
colors=[(49,56,61),(32,34,35),(105,62,33),(62,72,46),(143,150,153),(150,112,53),(15,18,20),(91,65,28)]
canvas=QImage(1024,512,QImage.Format.Format_ARGB32);rng=random.Random(430)
for tile,base in enumerate(colors):
 x0=tile%4*256;y0=(1-tile//4)*256
 for y in range(256):
  for x in range(256):
   sample=metal.pixelColor(x,y);lum=(sample.red()+sample.green()+sample.blue())/3
   variation=(lum-100)*.035+rng.gauss(0,.85)
   if tile==2:
    sample=wood.pixelColor(x,y);rgb=[sample.red()*1.14,sample.green()*.97,sample.blue()*.77]
   else:rgb=[c+variation for c in base]
   if tile in [1,3]:rgb=[v+1.1*math.sin(x*1.3)*math.sin(y*1.2) for v in rgb]
   canvas.setPixelColor(x0+x,y0+y,QColor(*[max(0,min(255,int(v))) for v in rgb]))
ink=QImage(1024,512,QImage.Format.Format_ARGB32);ink.fill(Qt.GlobalColor.transparent);p=QPainter(ink)
for tile in [0,4,5]:
 x0=tile%4*256;y0=(1-tile//4)*256
 for i in range(50):
  x=rng.randint(12,243);y=rng.randint(12,243)
  p.setPen(QPen(QColor(174,180,179,15 if tile==0 else 11),1));p.drawLine(x0+x,y0+y,x0+min(244,x+rng.randint(1,8)),y0+y)
p.end()
d=Krita.instance().createDocument(1024,512,'Realistic firearm surfaces','RGBA','U8','',72.0);d.setBatchmode(True)
for name,img in [('Recolored photographic grain',canvas),('Restrained handling wear',ink)]:
 layer=d.createNode(name,'paintlayer');d.rootNode().addChildNode(layer,None);bits=img.bits();bits.setsize(img.sizeInBytes());layer.setPixelData(QByteArray(bytes(bits)),0,0,1024,512)
d.refreshProjection();d.waitForDone();d.setFileName(str(root/'realistic-surfaces.kra'));d.save();d.projection(0,0,1024,512).save(str(root/'realistic-surfaces.png'))
Krita.instance().activeWindow().addView(d)
result={'file':d.fileName(),'layers':[n.name() for n in d.rootNode().childNodes()]}
