"""Continuous carved facial relief and anatomically nested eyes/lips for v2."""
import math

BOTTOM, TOP = 3.05, 8.12
EYE_Z, EYE_X = 6.97, .475
EYE_Y, EYE_W, EYE_D, EYE_H = -.94, .352, .22, .365

def body_radius(z):
    u=(z-BOTTOM)/(TOP-BOTTOM)
    return .955+.085*u+.014*math.sin(math.pi*u)-.055*math.exp(-u*65)-.052*math.exp(-(1-u)*65)

def relief(x,z):
    def mound(cx,cz,sx,sz,depth):
        return depth*math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
    # Nose, muzzle and chin are sculpted INTO the body surface.
    d=mound(0,6.89,.135,.56,.36)+mound(0,6.39,.17,.22,.24)
    d+=mound(0,6.275,.205,.11,.12)
    d+=mound(0,6.025,.43,.18,.20)+mound(0,5.55,.39,.25,.16)
    # Shallow continuous mouth groove, not a wire or separate cylindrical lip.
    smile_z=5.90+.115*(min(1,abs(x)/.58)**1.7)
    d-=.09*math.exp(-(x/.53)**6-((z-smile_z)/.048)**2)
    for sign in (-1,1):
        d+=mound(sign*.55,6.46,.32,.30,.335)
        d+=mound(sign*.48,7.46,.40,.21,.285)
        d+=mound(sign*.47,7.22,.39,.28,.11)
        d+=mound(sign*.19,6.27,.135,.11,.20)
        d+=mound(sign*.48,EYE_Z,.30,.30,-.245)
        # The smile crease separates the lifted cheek from the muzzle.
        if 5.98<z<6.40:
            ridge=.22+(6.40-z)*.70
            d+=mound(sign*ridge,6.17,.105,.22,.07)
    return d

def surface(x,z):
    r=body_radius(z)
    radial=math.sqrt(max(.0001,r*r-x*x))
    return -radial-relief(x,z)*(radial/r)**3

def build_face(api):
    bpy=api['bpy'];sphere=api['sphere'];path=api['path'];add=api['add']
    WOOD,WHITE,IRIS,BLACK,SHADOW=map(api.get,('WOOD','WHITE','IRIS','BLACK','SHADOW'))
    def mesh(name,vertices,faces,material):
        data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
        return add(obj,name,material)
    # Fuse a genuine rounded nose underside into the carved body. A height
    # field alone cannot form the human nasal overhang seen in the reference.
    body=api['body'];art,own=api['ART'],api['OWN']
    nasal=[sphere('NasalTipVolume',(0,-1.40,6.29),(.215,.195,.13),WOOD)]
    for side in (-1,1):
        nasal.append(sphere('NasalWingVolume_'+str(side),(side*.177,-1.28,6.26),(.125,.155,.095),WOOD))
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True)
    for obj in nasal:
        obj.select_set(True);art.remove(obj);own.pop(obj,None)
    bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
    remesh=body.modifiers.new('Continuous sculpted nose','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.014
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=body.modifiers.new('Blend nasal tissue','SMOOTH');smooth.factor=.45;smooth.iterations=2
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for polygon in body.data.polygons:polygon.use_smooth=True
    for sign,side in ((-1,'R'),(1,'L')):
        xc=sign*EYE_X
        # Iris and pupil follow the eyeball's true ellipsoidal surface.
        # They are not little spheres glued onto the sclera.
        def eye_cap(name,rx,rz,offset,material):
            vertices=[];faces=[];radial=14;around=96
            for ring in range(radial+1):
                r=max(.0001,ring/radial)
                for j in range(around):
                    angle=math.tau*j/around
                    dx=rx*r*math.cos(angle)-(0 if material==WHITE else sign*.012)
                    dz=rz*r*math.sin(angle)-(0 if material==WHITE else .006)
                    # Trim all ocular surfaces to the same almond aperture.
                    # Hidden white globe portions must not leak through cheeks.
                    height=.235 if dz>=0 else .242
                    maximum=height*math.sqrt(max(0,1-(dx/.327)**2))
                    dz=max(-maximum,min(maximum,dz))
                    y=EYE_Y-EYE_D*math.sqrt(max(.01,1-(dx/EYE_W)**2-(dz/EYE_H)**2))-offset
                    vertices.append((xc+dx,y,EYE_Z+dz))
            for ring in range(radial):
                for j in range(around):
                    a=ring*around+j;b=ring*around+(j+1)%around
                    faces.append((a,a+around,b+around,b))
            mesh(name,vertices,faces,material)
        eye_cap('Eye_'+side,.327,.242,.000,WHITE)
        eye_cap('Iris_'+side,.25,.266,.004,IRIS)
        eye_cap('Pupil_'+side,.211,.223,.007,BLACK)
        dx,dz=-.058,.101
        shine_y=EYE_Y-EYE_D*math.sqrt(1-(dx/EYE_W)**2-(dz/EYE_H)**2)-.012
        sphere('Catchlight_'+side,(xc+dx,shine_y,EYE_Z+dz),(.035,.006,.042),WHITE,segments=24,rings=16)
        # Radial eyelid skin patch. Its outer boundary sinks into the original
        # sculpt; the inner almond edge sits on the actual eyeball surface.
        vertices=[];faces=[];segments=128;rings=14
        for ring in range(rings+1):
            t=ring/rings;e=t*t*(3-2*t)
            for j in range(segments):
                theta=math.tau*j/segments;co,si=math.cos(theta),math.sin(theta)
                ix=.327*co;iz=(.235 if si>=0 else .242)*si
                ox=.465*co;oz=(.535 if si>=0 else .32)*si
                x=xc+ix*(1-e)+ox*e;z=EYE_Z+iz*(1-e)+oz*e
                eyeball=EYE_Y-EYE_D*math.sqrt(max(.025,1-(ix/EYE_W)**2-(iz/EYE_H)**2))-.016
                outer=surface(x,z)+.004
                fullness=(.036 if si>0 else .028)*math.sin(math.pi*t)
                y=eyeball*(1-e)+outer*e-fullness
                vertices.append((x,y,z))
        for ring in range(rings):
            for j in range(segments):
                a=ring*segments+j;b=ring*segments+(j+1)%segments
                faces.append((a,a+segments,b+segments,b))
        mesh('SculptedOrbitalSkin_'+side,vertices,faces,WOOD)
        # Very thin wet edge; the wide brow/hood is the continuous skin above.
        upper=[];lower=[]
        for j in range(49):
            theta=math.pi*j/48
            for points,angle in ((upper,theta),(lower,-theta)):
                dx=.327*math.cos(angle);dz=(.235 if angle>=0 else .242)*math.sin(angle)
                y=EYE_Y-EYE_D*math.sqrt(max(.025,1-(dx/EYE_W)**2-(dz/EYE_H)**2))-.019
                points.append((xc+dx,y,EYE_Z+dz))
        path('UpperLidMargin_'+side,upper,.015,WOOD)
        path('LowerLidMargin_'+side,lower,.011,WOOD)
    # Small recessed nostrils under a broad, integrated nose; no button sphere.
    for sign in (-1,1):
        x,z=sign*.155,6.225
        sphere('Nostril_'+str(sign),(x,-1.493,z),(.064,.016,.027),SHADOW,segments=32,rings=20)
        pts=[]
        for j in range(17):
            t=j/16;x=sign*(.11+.16*t);z=6.245+.055*math.sin(math.pi*t)
            pts.append((x,surface(x,z)-.007,z))
        path('AlarFold_'+str(sign),pts,.011,WOOD)
    # Dark lip opening follows a shallow asymmetric smile. Human lips are broad
    # sculpted skin ribbons whose edges merge into the muzzle, never tubes.
    def line(x):return 5.90+.115*(abs(x)/.58)**1.7+.018*x/.58
    verts=[];faces=[];count=96
    for i in range(count+1):
        x=-.58+1.16*i/count;u=x/.58;width=.029*max(0,1-u*u)**.6
        for sign in (-1,1):
            z=line(x)+sign*width
            verts.append((x,surface(x,z)-.004,z))
    for i in range(count):faces.append((i*2,(i+1)*2,(i+1)*2+1,i*2+1))
    mesh('InsetMouthOpening',verts,faces,SHADOW)
    for upper in (True,False):
        verts=[];faces=[];rows=12
        for i in range(count+1):
            x=-.61+1.22*i/count;u=x/.61;taper=max(0,1-u*u)**.6
            middle=line(max(-.58,min(.58,x)))
            inner=middle+(.029 if upper else -.029)*taper
            outer=middle+(.125 if upper else -.14)*taper
            for j in range(rows+1):
                v=j/rows;z=inner*(1-v)+outer*v
                fullness=(.036 if upper else .052)*math.sin(math.pi*v)**.75*taper
                y=surface(x,z)-fullness-.003
                verts.append((x,y,z))
        for i in range(count):
            for j in range(rows):
                a=i*(rows+1)+j;b=(i+1)*(rows+1)+j
                faces.append((a,b,b+1,a+1) if upper else (a,a+1,b+1,b))
        mesh('UpperLipSculpt' if upper else 'LowerLipSculpt',verts,faces,WOOD)
