import bpy
import os

global positions
positions = 'return { '

positions += 'mushrooms = { '
for ob in bpy.context.selected_objects:
    if 'shroom' in ob.name:
        positions += '%f,%f,%f' % ob.location[:] + ','
positions += ' },'

positions += ' crystals = { '
for ob in bpy.context.selected_objects:
    if 'crystal' in ob.name:
        positions += '%f,%f,%f' % ob.location[:] + ','
positions += ' }'

positions += ' }'

print(positions)

with open(os.environ['GROTTO_TOOLS_PATH'] + 'breadcrumb-data.lua','w') as file_object:
    file_object.write(positions)

# IN BLENDER, SELECT ALL OBJECTS
## import os
## filename = os.environ['GROTTO_TOOLS_PATH'] + "breadcrumb.py"
## exec(compile(open(filename).read(), filename, 'exec'))