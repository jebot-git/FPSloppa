from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[2]
items={
'launcher':('test-results/launcher/identity-launcher.png','Native launcher capture with coloured identity, avatar selection and direct connections.'),
'updater':('test-results/launcher-update/update-ui.png','Native updater test capture using a simulated 0.22v release; not a publication announcement.'),
'combat':('test-results/cs16/game-ak47.png','In-game desktop capture: AK-47 and arena HUD.'),
'stonehenge':('test-results/tribes-image-enhancer/stonehenge-normal.png','In-game desktop capture: Stonehenge with the Tribes disc launcher.'),
'ctf':('test-results/ctf-hyperborea-base.png','Engine-rendered objective view: a CTF home flag and capture ring.'),
'bomb':('test-results/defusal/bomb-keypad-cutters.png','Engine-rendered interaction fixture: planted bomb, keypad and cutters.'),
'cockpit':('test-results/ba2/gameplay/cockpit_feed_heat.png','Engine-rendered Titan cockpit fixture: health, armour, route and cannon heat.'),
'frigate':('test-results/community-views/as_frigate-0.png','Engine-rendered map view: Frigate harbour approach.'),
'vesper':('test-results/vesper/release-nave.png','Engine-rendered map view: Vesper Abbey nave.'),
'katabatic':('test-results/st-katabatic/central-valley.png','Engine-rendered map view: Katabatic central valley.'),
'pickups':('test-results/pickup-models-preview.png','Engine-rendered asset gallery: health, armour and ammunition supplies.'),
'cs-arsenal':('test-results/cs16/arsenal.png','Engine-rendered arsenal gallery: twelve CS weapons. Model details may vary with build.'),
'zoom':('test-results/tribes-image-enhancer/stonehenge-5x.png','In-game desktop capture: the Tribes image enhancer at 5×.')}
manifest=[]
for name,(src,caption) in items.items():
 im=Image.open(root/src).convert('RGB');im.thumbnail((1600,1000))
 dest=f'assets/{name}.webp';im.save(root/'docs/manual'/dest,'WEBP',quality=88)
 manifest.append({'asset':dest,'source':src,'caption':caption,'width':im.width,'height':im.height})
(root/'docs/manual/assets/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
