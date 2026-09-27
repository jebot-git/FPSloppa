"""Original deterministic diffuse atlas; eight padded 256px material tiles.

No downloaded pixels. Broad wear and grain remain legible after VR mipmapping;
fine noise is deliberately low contrast. Run in Blender's Python environment.
"""
import numpy as np

FINISH_NAMES=['Parkerized steel','Stippled polymer','Oiled walnut','Olive composite',
              'Machined steel','Cartridge brass','Recess black','Amber magazine']
FINISH_COLORS=[(80,89,98),(45,48,50),(133,72,35),(94,108,66),
               (163,170,174),(176,135,67),(22,25,28),(110,84,41)]

def make_finish(bpy,path):
 rng=np.random.default_rng(160927)
 size=256;y,x=np.mgrid[0:size,0:size]/(size-1)
 pixels=np.ones((size*2,size*4,4),dtype=np.float32)
 for k,color in enumerate(FINISH_COLORS):
  noise=rng.normal(0,1,x.shape)
  broad=np.sin(x*13+y*7)*np.sin(y*19-x*3)
  border=np.minimum.reduce([x,1-x,y,1-y])
  edge=np.exp(-((border-.055)/.013)**2)
  shade=1+noise*.018+broad*.035
  if k in [0,4,5]:
   shade+=np.sin(y*900+x*8)*.019+edge*(.32 if k==0 else .17)
   for _ in range(32):
    cx,cy=rng.uniform(.03,.97,2);length=rng.uniform(.025,.20)
    line=np.exp(-((y-cy-(x-cx)*.09)/.0018)**2)
    shade+=line*(np.abs(x-cx)<length)*rng.uniform(.03,.10)
   shade-=np.exp(-((x-.55)**2/.03+(y-.60)**2/.06))*.085
  elif k in [1,3]:
   stipple=(np.sin(x*430)*np.sin(y*420))
   shade+=stipple*.045+edge*.10
   shade-=np.maximum(0,np.sin(x*27+y*31))**24*.035
  elif k==2:
   grain=np.sin(y*150+np.sin(x*5)*3+np.sin(x*18+y*9)*.55)
   shade+=grain*.035+np.sin(y*54+np.sin(x*4)*2)*.045
   shade-=np.maximum(0,np.sin(y*270+np.sin(x*6)*5))**18*.045
   shade+=edge*.12
  elif k==6:shade+=np.sin(x*190+y*170)*.018
  else:
   shade+=np.cos(x*44)*.045+edge*.17
  rgb=np.clip(np.array(color)[None,None,:]/255*shade[:,:,None],0,1)
  # A wide flat gutter prevents coloured neighbours leaking into mip levels.
  rgb[:8]=rgb[8];rgb[-8:]=rgb[-9];rgb[:,:8]=rgb[:,8:9];rgb[:,-8:]=rgb[:,-9:-8]
  pixels[(k//4)*size:(k//4+1)*size,(k%4)*size:(k%4+1)*size,:3]=rgb
 image=bpy.data.images.new('CS16 original material atlas',width=size*4,height=size*2,alpha=True)
 image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(path)
 formats=[i.identifier for i in image.bl_rna.properties['file_format'].enum_items]
 assert 'PNG' in formats;image.file_format='PNG';image.save();image.pack()
 # Preserve the editable Krita finish across geometry rebuilds.
 painted=path.with_name('cs16-finish-painted.png')
 if painted.exists():
  image=bpy.data.images.load(str(painted),check_existing=False);image.pack()
 return image

def apply_finish(ob):
 """Map longitudinal grain along the part, with a padded island per face."""
 mesh=ob.data;uv=mesh.uv_layers.active
 if uv is None:uv=mesh.uv_layers.new(name='Material atlas')
 points=np.array([v.co[:] for v in mesh.vertices]);low=points.min(0);span=np.maximum(.001,points.max(0)-low)
 for face in mesh.polygons:
  normal=face.normal;axis=max(range(3),key=lambda i:abs(normal[i]))
  axes=[i for i in [1,0,2] if i!=axis] # length first, so walnut grain follows stock.
  mat=mesh.materials[face.material_index]
  tile=next((i for i,name in enumerate(FINISH_NAMES) if name in mat.name),0)
  for loop in face.loop_indices:
   p=mesh.vertices[mesh.loops[loop].vertex_index].co
   u=.055+.89*(p[axes[0]]-low[axes[0]])/span[axes[0]]
   v=.055+.89*(p[axes[1]]-low[axes[1]])/span[axes[1]]
   uv.data[loop].uv=((tile%4+u)/4,(tile//4+v)/2)
