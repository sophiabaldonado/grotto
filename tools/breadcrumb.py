from mathutils import Vector
import bpy
import os

positions = 'return { '

positions += 'mushrooms = { '
for ob in bpy.context.selected_objects:
    if 'shroom' in ob.name:
        local_bbox_center = 0.125 * sum((Vector(b) for b in ob.bound_box), Vector())
        global_bbox_center = ob.matrix_world @ local_bbox_center
        positions += '{ ' + '%f,%f,%f' % global_bbox_center[:] + ' },'
positions += ' },'

positions += ' crystals = { '
for ob in bpy.context.selected_objects:
    if 'crystal' in ob.name:
        local_bbox_center = 0.125 * sum((Vector(b) for b in ob.bound_box), Vector())
        global_bbox_center = ob.matrix_world @ local_bbox_center
        positions += '{ ' + '%f,%f,%f' % global_bbox_center[:] + ' },'
positions += ' },'


positions += ' drips = { '
for ob in bpy.context.selected_objects:
    if 'drip' in ob.name:
        local_bbox_center = 0.125 * sum((Vector(b) for b in ob.bound_box), Vector())
        global_bbox_center = ob.matrix_world @ local_bbox_center
        positions += '{ ' + '%f,%f,%f' % global_bbox_center[:] + ' },'
positions += ' }'

positions += ' }'

print(positions)

with open(os.environ['GROTTO_TOOLS_PATH'] + 'breadcrumb-data.lua','w') as file_object:
    file_object.write(positions)

# IN BLENDER, SELECT ALL OBJECTS
## import os
## filename = os.environ['GROTTO_TOOLS_PATH'] + "breadcrumb.py"
## exec(compile(open(filename).read(), filename, 'exec'))