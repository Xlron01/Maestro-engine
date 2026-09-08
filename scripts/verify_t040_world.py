import json

with open(r'C:\tmp\maestro engine\data\worlds\politics\t040_world.json', 'r') as f:
    w = json.load(f)

# Verify structure
print('=== World Fixture Verification ===')
print(f'World ID: {w["world_id"]}')
countries = set(k.split('_')[0] for k in w['legislatures'])
print(f'Countries: {len(countries)}')
print(f'Legislatures: {len(w["legislatures"])}')
print(f'Parties: {len(w["parties"])}')
print(f'Offices: {len(w["offices"])}')
print(f'Characters: {len(w["characters"])}')

# Check a sample country
sample = 'AlphaPrime_000'
print(f'\n=== Sample Country: {sample} ===')
print(f'Parties: {[k for k in w["parties"] if k.startswith(sample)]}')
print(f'Legislature: {sample}_parliament in legislatures: {sample}_parliament in w["legislatures"]')
print(f'Offices: {[k for k in w["offices"] if k.startswith(sample)]}')
print(f'Characters: {[k for k in w["characters"] if k.startswith(sample)]}')

# Verify institutional rules reference
print('\n=== Institutional Rules Compatibility ===')
for oid, odata in list(w['offices'].items())[:3]:
    print(f'{oid}: institution={odata["institution_id"]}, role={odata["role"]}')

# Check legislature structure
for lid, ldata in list(w['legislatures'].items())[:1]:
    total_seats = sum(ldata['seats'].values())
    print(f'{lid}: parties={list(ldata["seats"].keys())[:3]}... total_seats={total_seats}')

# Verify party electoral strengths sum to ~1.0 per country
print('\n=== Party Strength Verification ===')
for c in list(countries)[:5]:
    parties = [p for p in w['parties'] if p.startswith(c + '_P')]
    total_strength = sum(w['parties'][p]['political_profile']['electoral_strength'] for p in parties)
    print(f'{c}: {len(parties)} parties, total_strength={total_strength:.4f}')