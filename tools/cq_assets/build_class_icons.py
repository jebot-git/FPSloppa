"""Original CQ class icon font; glyphs only, normal text uses Godot's fallback font."""
from pathlib import Path
from math import sin,cos,pi
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
root=Path(__file__).resolve().parents[2]
def polygon(pen,points):
 pen.moveTo(points[0])
 for p in points[1:]:pen.lineTo(p)
 pen.closePath()
def circle(pen,r,reverse=False):
 points=[(round(500+r*cos(i*2*pi/48)),round(350+r*sin(i*2*pi/48))) for i in range(48)]
 polygon(pen,points[::-1] if reverse else points)
glyphs={}
pen=TTGlyphPen(None);glyphs['.notdef']=pen.glyph()
pen=TTGlyphPen(None);polygon(pen,[(540,800),(180,290),(450,290),(370,-80),(820,460),(540,460)]);glyphs['shocktroop']=pen.glyph()
pen=TTGlyphPen(None);circle(pen,365);circle(pen,265,True);circle(pen,70);glyphs['scout']=pen.glyph()
pen=TTGlyphPen(None);polygon(pen,[(380,-20),(620,-20),(620,230),(870,230),(870,470),(620,470),(620,720),(380,720),(380,470),(130,470),(130,230),(380,230)]);glyphs['medic']=pen.glyph()
pen=TTGlyphPen(None)
polygon(pen,[(round(500+(410 if i%4 in (1,2) else 320)*cos(i*pi/16)),round(350+(410 if i%4 in (1,2) else 320)*sin(i*pi/16))) for i in range(32)])
circle(pen,150,True);glyphs['technician']=pen.glyph()
font=FontBuilder(1000,isTTF=True);font.setupGlyphOrder(list(glyphs));font.setupCharacterMap(dict(zip([0xe000,0xe001,0xe002,0xe003],list(glyphs)[1:])))
font.setupGlyf(glyphs);font.setupHorizontalMetrics({g:(1000,0) for g in glyphs});font.setupHorizontalHeader(ascent=850,descent=-150)
font.setupNameTable({'familyName':'CQ Class Icons','styleName':'Regular','uniqueFontIdentifier':'CQ Class Icons 1','fullName':'CQ Class Icons','psName':'CQClassIcons','version':'Version 1.0','copyright':'Original CQ prototype artwork, CC0.'})
font.setupOS2(sTypoAscender=850,sTypoDescender=-150,usWinAscent=850,usWinDescent=150);font.setupPost();font.setupMaxp()
font.save(root/'deathmatch/conquest/classes/icons/class_icons.ttf')
