"""Editable CS 1.6 tactical lanes; project coordinates, never retail geometry.
Run after map compilation to bind the profiles to installed BSP hashes.
"""
from pathlib import Path
import hashlib, json
ROOT=Path(__file__).resolve().parents[2]
def p(u,v,z=0):return [round((v-300)*6/32,5),round(z/32+.05,5),round((400-u)*6/32,5)]
def az(x,y,z=64):return [400+x/8,300-y/8,z]
def lane(name,*points):return dict(name=name,points=[p(*q) for q in points])
def hold(name,at,watch):return dict(name=name,position=p(*at),watch=p(*watch))
def profiles():
    return {
    'dust2':dict(attacks=[[
        lane('long',[650,329,128],[615,223,0],[480,183,0],[410,58,0],[182,100,224]),
        lane('short',[600,297,128],[342,297,128],[342,213,128],[215,213,224],[215,183,224])], [
        lane('tunnels',[520,520,64],[387,517,64],[300,563,64],[218,531,64]),
        lane('mid split',[550,329,118],[313,322,0],[207,410,34],[237,476,64],[237,519,64])]],
        holds=[[hold('long cross',[182,100,224],[275,58,172]),hold('short stairs',[215,183,224],[308,213,164]),hold('A rear',[158,137,224],[215,183,224])],
               [hold('tunnel exit',[218,531,64],[280,563,64]),hold('doors',[237,519,64],[237,476,64]),hold('window',[180,480,64],[164,459,104])]]),
    'nuke':dict(attacks=[[
        lane('hut',[320,340,0],[427,320,0],[461,320,0],[478,348,0]),
        lane('outside main',[320,420,0],[580,480,0],[608,379,0],[578,306,0],[548,367,0])],[
        lane('radio ramp',[385,316,0],[408,248,0],[448,143,0],[490,143,0],[490,270,-256],[457,350,-256]),
        lane('garage lower',[320,420,0],[608,480,0],[704,480,0],[732,443,0],[732,550,-256],[606,408,-256],[585,484,-256],[548,484,-256],[547,372,-256])]],
        holds=[[hold('hut exit',[461,320,0],[433,320,0]),hold('main',[548,367,0],[578,306,0]),hold('upper rear',[478,367,0],[447,365,0])],
               [hold('ramp landing',[457,285,-256],[490,270,-256]),hold('lower east',[547,372,-256],[585,408,-256]),hold('lower cross',[479,372,-256],[457,350,-256])]]),
    'inferno':dict(attacks=[[
        lane('mid',[257,423,0],[510,430,0],[510,515,0],[590,479,0],[646,452,0]),
        lane('apartments',[175,579,0],[407,540,0],[400,596,6],[470,596,96],[594,571,96],[594,493,0],[646,452,0])],[
        lane('banana',[257,423,0],[303,303,0],[360,230,0],[387,162,0],[372,96,0])]],
        holds=[[hold('site',[646,452,0],[590,479,0]),hold('pit mouth',[674,521,0],[594,535,74]),hold('library',[596,383,0],[510,346,0])],
               [hold('banana',[372,96,0],[387,162,0]),hold('B back',[385,115,0],[372,136,0]),hold('CT arch',[419,87,0],[387,123,0])]]),
    'aztec':dict(attacks=[[
        lane('central doors',az(1728,96,0),az(1344,192),az(128,128),az(-32,-1120),az(-608,-1464)),
        lane('canal A',az(1216,800),az(320,448),az(-704,448,-256),az(-704,-1120,-256),az(-32,-1120),az(-608,-1464))],[
        lane('bridge',az(1904,448,0),az(1904,736),az(160,704),az(-960,704),az(-1728,864),az(-2064,960)),
        lane('canal B',az(1216,800),az(320,448),az(-704,448,-256),az(-1536,448),az(-1536,560),az(-1408,560),az(-1408,704),az(-1728,704),az(-1728,864),az(-2064,960))]],
        holds=[[hold('A entrance',az(-608,-1464),az(-32,-1440)),hold('A rear',az(-1088,-1472),az(-608,-1464)),hold('CT doors',az(-1376,-1152),az(-2160,-1152))],
               [hold('bridge exit',az(-1728,864),az(-1536,704)),hold('B rear',az(-2480,864),az(-2064,960)),hold('central turn',az(-2064,384),az(-1200,-384))]]),
    'train':dict(attacks=[[
        lane('main',[227,180,0],[229,249,0],[284,249,0],[609,249,0],[609,356,0]),
        lane('ivy',[229,54,0],[556,54,0],[556,198,0],[607,247,0],[610,355,0])],[
        lane('lower halls',[227,180,0],[243,377,0],[243,482,0],[260,546,0],[414,546,0]),
        lane('upper halls',[227,180,0],[182,250,0],[182,333,96],[182,400,85],[243,482,0],[260,546,0],[414,546,0])]],
        holds=[[hold('bomb train',[558,356,0],[450,344,0]),hold('ivy cross',[609,300,0],[556,198,0]),hold('main cross',[284,249,0],[229,249,0])],
               [hold('inner plant',[414,546,0],[260,546,0]),hold('inner entry',[260,505,0],[243,482,0]),hold('Z entry',[565,505,0],[560,436,0])]])}
def main():
    rows={}
    for name,row in profiles().items():
        key='de_'+name+'_rebuilt'
        row['sha256']=hashlib.sha256((ROOT/'maps'/f'{key}.bsp').read_bytes()).hexdigest()
        rows[key]=row
    (ROOT/'deathmatch/maps/defusal_tactics.json').write_text(json.dumps(rows,indent=2)+'\n')
if __name__=='__main__':main()
