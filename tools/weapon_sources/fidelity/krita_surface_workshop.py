from PyQt6.QtGui import QImage,QPainter,QColor,QPen,QFont
from PyQt6.QtCore import Qt,QByteArray
from pathlib import Path
from krita import InfoObject
root=Path('/home/blux/Documents/FPSloppa/tools/weapon_sources/fidelity')
base=QImage(str(root/'material-swatches.png'))
d=doc
d.setBatchmode(True)
for node in list(d.rootNode().childNodes()):node.remove()
canvas=QImage(1024,512,QImage.Format.Format_ARGB32);canvas.fill(Qt.GlobalColor.transparent)
p=QPainter(canvas)
for i in range(8):
 x=(i%4)*256;y=(i//4)*256
 tile=base.copy(int((i%4)*base.width()/4+5),int((i//4)*base.height()/2+5),int(base.width()/4-10),int(base.height()/2-10))
 p.drawImage(x,y,tile.scaled(256,256,Qt.AspectRatioMode.IgnoreAspectRatio,Qt.TransformationMode.SmoothTransformation))
p.end()
layer=d.createNode('Material grain and patina','paintlayer');d.rootNode().addChildNode(layer,None)
ptr=canvas.bits();ptr.setsize(canvas.sizeInBytes());layer.setPixelData(QByteArray(bytes(ptr)),0,0,1024,512)
ink=QImage(1024,512,QImage.Format.Format_ARGB32);ink.fill(Qt.GlobalColor.transparent);p=QPainter(ink);p.setRenderHint(QPainter.RenderHint.Antialiasing)
for i in range(8):
 x=(i%4)*256;y=(i//4)*256
 p.setBrush(Qt.BrushStyle.NoBrush);p.setPen(QPen(QColor(10,15,20,205),3));p.drawRoundedRect(x+14,y+17,226,220,9,9)
 p.setPen(QPen(QColor(195,195,183,90),1));p.drawRoundedRect(x+17,y+20,220,214,8,8)
 for bx,by in [(25,30),(230,30),(25,224),(230,224)]:
  p.setPen(QPen(QColor(8,11,14,220),2));p.setBrush(QColor(62,67,69,235));p.drawEllipse(x+bx-5,y+by-5,10,10)
  p.setPen(QPen(QColor(165,171,168,160),1));p.drawLine(x+bx-3,y+by+2,x+bx+3,y+by-2)
 for j in range(6):
  p.setPen(QPen(QColor(6,12,17,205),4));p.drawLine(x+42+j*26,y+63,x+48+j*26,y+95)
  p.setPen(QPen(QColor(164,171,174,65),1));p.drawLine(x+44+j*26,y+63,x+50+j*26,y+95)
 p.setPen(QColor(196,199,185,150));p.setFont(QFont('DejaVu Sans Mono',10));p.drawText(x+37,y+151,'FIELD SYSTEMS')
 p.setFont(QFont('DejaVu Sans Mono',7));p.drawText(x+38,y+170,'MK.%02d  //  SERVICE'%(i+1))
 p.setPen(QPen(QColor(10,15,20,150),2));p.drawLine(x+37,y+185,x+215,y+185)
p.end()
layer=d.createNode('Engraving, vents and fasteners','paintlayer');d.rootNode().addChildNode(layer,None)
ptr=ink.bits();ptr.setsize(ink.sizeInBytes());layer.setPixelData(QByteArray(bytes(ptr)),0,0,1024,512)
d.refreshProjection();d.waitForDone();d.setFileName(str(root/'weapon-panels.kra'));d.save();d.projection(0,0,d.width(),d.height()).save(str(root/'weapon-panels.png'))
result={'file':d.fileName(),'layers':[n.name() for n in d.rootNode().childNodes()],'size':[d.width(),d.height()]}
