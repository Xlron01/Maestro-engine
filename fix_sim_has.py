with open(r'C:\tmp\maestro engine\scripts\game_event_handlers.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('if _sim.has("data_root_override"):', 'if _sim.data_root_override != "":')
with open(r'C:\tmp\maestro engine\scripts\game_event_handlers.gd', 'w', encoding='ascii') as f:
    f.write(content)
print('Fixed')