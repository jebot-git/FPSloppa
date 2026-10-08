#!/usr/bin/env python3
"""Validate the delivered manual's links and PDF navigation (requires pypdf)."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote,urlsplit
from collections import Counter
import json
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parents[2]
manual=ROOT/'docs/manual'
class Parser(HTMLParser):
 def __init__(self):super().__init__();self.ids=[];self.links=[];self.images=[];self.diagrams=0
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.append(a['id'])
  if tag=='a' and 'href' in a:self.links.append(a['href'])
  if tag in ['script','img'] and 'src' in a:self.links.append(a['src'])
  if tag=='link' and 'href' in a:self.links.append(a['href'])
  if tag=='img':self.images.append(a)
  if tag=='svg':self.diagrams+=1
p=Parser();p.feed((manual/'index.html').read_text())
assert len(p.ids)==len(set(p.ids)),'Duplicate IDs'
for link in p.links:
 u=urlsplit(link)
 if u.scheme:continue
 if not u.path:assert u.fragment in p.ids,link
 else:assert (manual/unquote(u.path)).exists(),link
assert all(x.get('alt') and x.get('width') and x.get('height') for x in p.images)
r=PdfReader(manual/'FPSloppa-Player-Manual.pdf')
page_ids={page.indirect_reference.idnum for page in r.pages}
counts=Counter()
for page in r.pages:
 text=page.extract_text()
 assert len(text)>100,'Nearly empty PDF page'
 for ref in page.get('/Annots',[]):
  a=ref.get_object()
  if a.get('/Subtype')!='/Link':continue
  if '/Dest' in a:
   d=a['/Dest']
   if isinstance(d,str):
    assert str(d) in r.named_destinations,'Unknown named PDF destination'
    assert r.get_destination_page_number(r.named_destinations[str(d)]) in range(len(r.pages)),'Broken named PDF destination'
   else:assert d[0].idnum in page_ids,'Broken PDF destination'
   counts['internal_links']+=1
  if '/A' in a:
   action=a['/A'];assert action.get('/S')=='/URI',action
   assert str(action['/URI']).startswith('https://'),action
   counts['external_links']+=1
fulltext='\n'.join(page.extract_text() for page in r.pages)
for word in ['Titanball','Defusal','Tribes','Quake','UT99','Chainsaw','Instafreeze','Virtual Stock','PLAY IN VR','UPDATE TO','Shadows Awaken Within','Devoted Guard','Climax','Scara Brae','Shrike','Jericho','MP5: lock first','18 visible characters']:
 assert word.lower() in fulltext.lower(),word
assert r.outline,'Missing PDF bookmarks'
assert '8fbf5c8' not in fulltext and '3 October 2026' not in fulltext,'Outdated edition text'
for chapter in ['launcher','music','vehicles','reload','session']:
 assert chapter in p.ids,chapter
def outline_count(items):return sum(outline_count(x) if isinstance(x,list) else 1 for x in items)
result={'pdf_pages':len(r.pages),'screenshots_and_rendered_views':len(p.images),'svg_infographics':p.diagrams,'pdf_bookmarks':outline_count(r.outline),**dict(counts),'local_links_valid':True,'pdf_destinations_valid':True,'machine_specific_pdf_links':False}
(ROOT/'tools/manual/validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
