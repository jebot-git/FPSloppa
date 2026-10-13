from PyQt6.QtGui import QImage, QPainter, QColor, QPen, QPainterPath
from PyQt6.QtCore import Qt, QByteArray
import random
random.seed(1977)
doc.scaleImage(1024,1024,300,300,"Bicubic")
for title in ['Trunks and branches','Broadleaf crowns','Palm fronds']:
 node=doc.createNode(title,'paintlayer');doc.rootNode().addChildNode(node,None)
 im=QImage(1024,1024,QImage.Format.Format_ARGB32);im.fill(Qt.GlobalColor.transparent)
 p=QPainter(im);p.setRenderHint(QPainter.RenderHint.Antialiasing)
 if title=='Trunks and branches':
  p.setPen(QPen(QColor('#72533a'),19));p.drawLine(256,997,256,302);p.drawLine(764,997,748,241)
  p.setPen(QPen(QColor('#987552'),6));p.drawLine(250,990,250,315)
  for ex,ey in [(114,362),(371,321),(120,520),(392,506)]:p.drawLine(256,650,ex,ey)
 elif title=='Broadleaf crowns':
  p.setPen(Qt.PenStyle.NoPen)
  for cx,cy,rx,ry in [(253,264,205,181),(167,457,135,102),(347,436,115,119)]:
   for i in range(64):
    x=cx+random.uniform(-rx*.8,rx*.8);y=cy+random.uniform(-ry*.7,ry*.7)
    r=random.randint(19,52);p.setBrush(QColor(random.choice(['#24482e','#30623a','#3b7843','#49834c','#5a914f'])));p.drawEllipse(int(x-r),int(y-r*.65),r*2,int(r*1.3))
  p.setBrush(QColor('#629751'))
  for i in range(85):
   x=random.randrange(90,414);y=random.randrange(157,538);p.drawEllipse(x,y,random.randrange(6,15),5)
 else:
  for dx,dy in [(-200,40),(-160,-100),(-90,-170),(70,-180),(172,-110),(216,5),(160,115),(-150,134)]:
   path=QPainterPath();path.moveTo(748,247);path.quadTo(748+dx*.6,247+dy*.55-40,748+dx,247+dy)
   p.setPen(QPen(QColor('#356c3f'),13));p.drawPath(path)
   for j in range(2,15):
    t=j/16.;x=748+dx*t;y=247+dy*t-70*t*(1-t)
    p.setPen(QPen(QColor('#4e8750'),6));p.drawLine(int(x),int(y),int(x+dx*.05-23),int(y+23));p.drawLine(int(x),int(y),int(x+dx*.05+20),int(y+15))
 p.end();ptr=im.bits();ptr.setsize(im.sizeInBytes());node.setPixelData(QByteArray(bytes(ptr)),0,0,1024,1024)
doc.refreshProjection()
result={'layers':[n.name() for n in doc.rootNode().childNodes()],'atlas':'left broadleaf, right palm, transparent 1024x1024'}
