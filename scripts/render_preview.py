#!/usr/bin/env python3
"""Optional geometry contact sheets (NumPy/Pillow); not Roblox engine screenshots.

First run the Lune scene exporter with --geometry. This renderer projects the
actual transformed Parts from that export. It approximates materials/light and
omits GUI text, particles and physics, so Studio visual review remains necessary.
"""
from pathlib import Path
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

def mesh(shape):
    if shape == 'Ball':
        rings, segments = 9, 14
        verts = []
        for i in range(rings + 1):
            lat = -math.pi / 2 + math.pi * i / rings
            for j in range(segments):
                lon = 2 * math.pi * j / segments
                verts.append([math.cos(lat)*math.cos(lon)/2, math.sin(lat)/2, math.cos(lat)*math.sin(lon)/2])
        faces=[]
        for i in range(rings):
            for j in range(segments):
                a=i*segments+j; b=i*segments+(j+1)%segments; c=(i+1)*segments+j; d=(i+1)*segments+(j+1)%segments
                faces.extend(((a,c,b),(b,c,d)))
    elif shape == 'Cylinder':
        n=14
        verts=[[side,math.cos(j*math.tau/n)/2,math.sin(j*math.tau/n)/2] for side in (-.5,.5) for j in range(n)]
        verts += [[-.5,0,0],[.5,0,0]]
        faces=[]
        for j in range(n):
            k=(j+1)%n
            faces.extend(((j,k,n+j),(k,n+k,n+j),(2*n,k,j),(2*n+1,n+j,n+k)))
    elif shape == 'Wedge':
        verts=[[-.5,-.5,-.5],[.5,-.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]]
        faces=[(0,1,2),(1,3,2),(2,3,4),(3,5,4),(0,4,1),(1,4,5),(0,2,4),(1,5,3)]
    else:
        verts=[[-.5,-.5,-.5],[.5,-.5,-.5],[-.5,.5,-.5],[.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]]
        faces=[(0,2,1),(1,2,3),(4,5,6),(5,7,6),(0,1,4),(1,5,4),(2,6,3),(3,6,7),(0,4,2),(2,4,6),(1,3,5),(3,7,5)]
    vertices=np.array(verts,float); indices=np.array(faces,int)
    triangles=vertices[indices]
    normals=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
    inward=np.sum(normals*(triangles.mean(axis=1)-vertices.mean(axis=0)),axis=1)<0
    indices[inward]=indices[inward,::-1]
    return vertices,indices

MESHES={kind:mesh(kind) for kind in ('Ball','Cylinder','Wedge','Block')}

def render(parts, size, camera=(7,5,-11), background=(239,235,222)):
    width,height=size
    forward=-np.array(camera,dtype=float);forward/=np.linalg.norm(forward)
    right=np.cross(forward,[0,1,0]);right/=np.linalg.norm(right)
    up=np.cross(right,forward)
    basis=np.array([right,up,forward]).T
    light=np.array([-.5,1,-.8]);light/=np.linalg.norm(light)
    chunks=[]; points=[]
    for part in parts:
        if part['alpha']<.25: continue
        vertices,faces=MESHES.get(part['shape'],MESHES['Block'])
        cf=np.array(part['cf'])
        matrix=cf[3:].reshape(3,3)
        world=(vertices*np.array(part['size']))@matrix.T+cf[:3]
        tri=world[faces]
        normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
        norms=np.linalg.norm(normal,axis=1)
        keep=(norms>1e-10)&(normal@forward<0)
        tri=tri[keep];normal=normal[keep]/norms[keep,None]
        projected=tri@basis
        if not len(tri): continue
        diffuse=np.maximum(0,normal@light)
        shade=.62+.38*diffuse
        if part['material']=='Neon': shade=np.full_like(shade,.98)
        colors=np.clip(np.array(part['color'])[None,:]*shade[:,None]*255,0,255)
        # Preview only: reduce strongly transparent pieces rather than pretending
        # this painter's algorithm has Roblox's translucent material renderer.
        if part['alpha']<.65: colors=colors*part['alpha']+np.array(background)*(1-part['alpha'])
        chunks.append((projected,colors));points.append(projected.reshape(-1,3))
    allpoints=np.concatenate(points)
    minimum=allpoints[:,:2].min(axis=0);maximum=allpoints[:,:2].max(axis=0)
    scale=min(width*.84/(maximum[0]-minimum[0]),height*.82/(maximum[1]-minimum[1]))
    center=(minimum+maximum)/2
    image=Image.new('RGB',size,background)
    shadow=Image.new('RGBA',size,(0,0,0,0)); pen=ImageDraw.Draw(shadow)
    pen.ellipse((width*.22,height*.80,width*.78,height*.88),fill=(39,50,40,35))
    shadow=shadow.filter(ImageFilter.GaussianBlur(max(2,int(width*.018))))
    image=Image.alpha_composite(image.convert('RGBA'),shadow).convert('RGB')
    triangles=np.concatenate([c[0] for c in chunks]);colors=np.concatenate([c[1] for c in chunks])
    order=np.argsort(triangles[:,:,2].mean(axis=1))[::-1]
    pen=ImageDraw.Draw(image)
    if width<1000:
        for index in order:
            xy=(triangles[index,:,:2]-center)*scale
            xy[:,0]+=width/2;xy[:,1]=height*.46-xy[:,1]
            pen.polygon([tuple(p) for p in xy],fill=tuple(colors[index].astype(int)))
    else:
        # A real depth buffer is essential for large ground triangles: sorting
        # their centroids would paint the island floor over shops and trees.
        pixels=np.array(image)
        depth=np.full((height,width),np.inf,dtype=np.float32)
        for index in order:
            xy=(triangles[index,:,:2]-center)*scale
            xy[:,0]+=width/2;xy[:,1]=height*.46-xy[:,1]
            x0=max(0,int(np.floor(xy[:,0].min())));x1=min(width-1,int(np.ceil(xy[:,0].max())))
            y0=max(0,int(np.floor(xy[:,1].min())));y1=min(height-1,int(np.ceil(xy[:,1].max())))
            if x1<x0 or y1<y0:continue
            a,b,c=xy
            denominator=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(denominator)<1e-8:continue
            xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
            u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denominator
            v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denominator
            w=1-u-v
            z=u*triangles[index,0,2]+v*triangles[index,1,2]+w*triangles[index,2,2]
            region=depth[y0:y1+1,x0:x1+1]
            mask=(u>=0)&(v>=0)&(w>=0)&(z<region)
            pixels[y0:y1+1,x0:x1+1][mask]=colors[index].astype(np.uint8)
            region[mask]=z[mask]
        image=Image.fromarray(pixels)

    return image

def font(size,bold=False):
    name='/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if bold else '')+'.ttf'
    try:return ImageFont.truetype(name,size)
    except OSError:return ImageFont.load_default()

def main():
    content=json.loads((ROOT/'build/scene-geometry.json').read_text())
    output=ROOT/'build/previews';output.mkdir(exist_ok=True)
    w,h=720,650
    sheet=Image.new('RGB',(w*3,h*7+130),(239,235,222)); pen=ImageDraw.Draw(sheet)
    pen.text((38,24),'BRAINROT BLOOM / CREATURE SCULPTURES',font=font(30,True),fill=(34,53,43))
    pen.text((38,72),'Geometry previews • Actual Part positions and rotations • Studio materials and lighting may differ',font=font(20),fill=(92,108,93))
    for i,creature in enumerate(content['creatures']):
        image=render(creature['parts'],(w,h-110))
        draw=ImageDraw.Draw(image)
        image.save(output/(creature['id']+'.png'))
        x=(i%3)*w;y=(i//3)*h+130
        sheet.paste(image,(x,y))
        pen.text((x+34,y+h-100),creature['name'],font=font(25,True),fill=(34,53,43))
        pen.text((x+34,y+h-62),creature['rarity']+'  /  '+str(len(creature['parts']))+' sculpted pieces',font=font(21),fill=(92,108,93))
    sheet.resize((1080,2340),Image.Resampling.LANCZOS).save(output/'creature-contact-sheet.png')
    for world in content['worlds']:
        image=render(world['parts'],(1600,1200),camera=(1.1,1.0,-1.4),background=(222,236,230))
        ImageDraw.Draw(image).text((32,24),world['name']+' • geometry preview',font=font(28,True),fill=(30,50,42))
        image.save(output/(world['id'].lower()+'-map.png'))
    meadow=content['worlds'][0]
    village=[p for p in meadow['parts'] if abs(p['cf'][0])<128 and -190<p['cf'][2]<-30 and (max(p['size'])<90 or p['name'] in {'VillagePlaza','PlazaInlay','CentralWalkway'})]
    village.append({'shape':'Block','size':[275,.2,180],'cf':[0,.15,-110,1,0,0,0,1,0,0,0,1],'color':[.55,.66,.46],'alpha':1,'material':'Grass'})
    image=render(village,(1600,1100),camera=(.65,.75,-1.2),background=(222,236,230))
    ImageDraw.Draw(image).text((32,24),'Clover Village • geometry preview',font=font(28,True),fill=(30,50,42))
    image.save(output/'village-detail.png')
    if content.get('gardens'):
        image=render(content['gardens']['parts'],(1600,1200),camera=(1,1.1,1.5),background=(222,236,230))
        ImageDraw.Draw(image).text((32,24),'Six Personal Gardens • geometry preview',font=font(28,True),fill=(30,50,42))
        image.save(output/'personal-gardens.png')
    print('Rendered original creature contact sheet and three map geometry previews in build/previews/')

if __name__=='__main__':main()
