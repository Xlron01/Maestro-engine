#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TASK-040 World Fixture Generator
Deterministic 200-country political world for Actor Runtime benchmark.
TEST FIXTURE ONLY - not production game-balance data.
"""

import json
import random
import sys

# Deterministic seed
SEED = 20260908
random.seed(SEED)

# Country name pool - deterministic generation
def generate_country_names(n):
    """Generate n unique country names deterministically"""
    prefixes = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
                "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
                "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"]
    suffixes = ["Prime", "Secundus", "Tertius", "Quartus", "Quintus", "Sextus",
                "Septimus", "Octavus", "Nonus", "Decimus", "Undecimus", "Duodecimus",
                "Tertiusdecimus", "Quartusdecimus", "Quintusdecimus"]
    names = []
    for i in range(n):
        p_idx = i % len(prefixes)
        s_idx = (i // len(prefixes)) % len(suffixes)
        p = prefixes[p_idx]
        s = suffixes[s_idx]
        names.append(f"{p}{s}_{i:03d}")
    return names

def generate_electoral_strengths(num_parties):
    """Generate deterministic electoral strengths summing to 1.0"""
    # Use Dirichlet-like distribution with fixed weights
    weights = [0.45, 0.30, 0.15, 0.07, 0.03][:num_parties]
    total = sum(weights)
    return [w / total for w in weights]

def generate_parties(country_id, base_idx, num_parties=3):
    """Generate deterministic parties for a country"""
    parties = {}
    strengths = generate_electoral_strengths(num_parties)
    ideologies = ["center", "center-left", "center-right", "left", "right", "populist", "technocratic"]
    
    for i in range(num_parties):
        p_id = f"{country_id}_P{i}"
        leader_id = f"{country_id}_c_leader_{i}"
        mp_id = f"{country_id}_c_mp_{i}"
        
        parties[p_id] = {
            "party_id": p_id,
            "leader": leader_id,
            "membership": [leader_id, mp_id],
            "political_profile": {
                "electoral_strength": strengths[i],
                "ideology": ideologies[(base_idx + i) % len(ideologies)]
            }
            # seats will be computed by legislature using largest remainder method
        }
    return parties, {p_id: f"{country_id}_c_leader_{i}" for i, p_id in enumerate(parties)}

def generate_characters(country_id, num_parties):
    """Generate deterministic characters for a country"""
    characters = {}
    # Head of state
    characters[f"{country_id}_c_king"] = {"name": f"Head of State {country_id}"}
    # Party leaders and MPs
    for i in range(num_parties):
        characters[f"{country_id}_c_leader_{i}"] = {"name": f"Leader {i} {country_id}"}
        characters[f"{country_id}_c_mp_{i}"] = {"name": f"MP {i} {country_id}"}
    return characters

def allocate_seats_largest_remainder(parties, total_seats=200):
    """Allocate seats using largest remainder method (same as election system)"""
    # Calculate raw quota for each party
    quotas = {}
    for p_id, p_data in parties.items():
        strength = p_data["political_profile"]["electoral_strength"]
        quotas[p_id] = strength * total_seats
    
    # Floor allocation
    seats = {}
    remainders = {}
    allocated = 0
    for p_id, q in quotas.items():
        floor = int(q)
        seats[p_id] = floor
        allocated += floor
        remainders[p_id] = q - floor
    
    # Distribute remaining seats by largest remainder
    remaining = total_seats - allocated
    # Sort by remainder descending, then by party_id for tie-breaking
    sorted_parties = sorted(remainders.items(), key=lambda x: (-x[1], x[0]))
    for i in range(remaining):
        p_id = sorted_parties[i][0]
        seats[p_id] += 1
    
    return seats

def generate_legislature(country_id, parties):
    """Generate deterministic legislature with seats matching party strengths using largest remainder"""
    seats = allocate_seats_largest_remainder(parties, 200)
    
    return {
        "legislature_id": f"{country_id}_parliament",
        "chambers": ["lower"],
        "seats": seats,
        "procedural_state": {"dissolved": False, "term": 1},
        "active_bills": [],
        "active_motions": []
    }

def generate_offices(country_id, num_parties):
    """Generate deterministic offices for a country"""
    return {
        f"{country_id}_office_president": {
            "office_id": f"{country_id}_office_president",
            "institution_id": f"{country_id}_inst_state",
            "role": "head_of_state",
            "holder": f"{country_id}_c_king",
            "status": "appointed"
        },
        f"{country_id}_office_pm": {
            "office_id": f"{country_id}_office_pm",
            "institution_id": f"{country_id}_inst_government",
            "role": "head_of_government",
            "holder": None,
            "status": "vacant"
        },
        f"{country_id}_office_finance": {
            "office_id": f"{country_id}_office_finance",
            "institution_id": f"{country_id}_inst_government",
            "role": "minister",
            "holder": None,
            "status": "vacant"
        }
    }

def generate_governments(country_id, parties, term_days=30):
    """Generate initial government (empty - will be formed via actions)"""
    return {}

def generate_government_support(parties):
    """Empty support initially"""
    return {}

def build_world():
    """Build the complete 200-country world fixture"""
    country_names = generate_country_names(200)
    
    world = {
        "world_id": "t040_benchmark_world",
        "description": "TASK-040 Actor Runtime benchmark fixture - 200 countries with political institutions. TEST FIXTURE VALUES - not production game-balance.",
        "fixture_metadata": {
            "seed": SEED,
            "num_countries": 200,
            "term_duration_days": 30,
            "test_horizon_days": 90,
            "note": "TEST FIXTURE VALUE - not production game-balance value"
        },
        "characters": {},
        "parties": {},
        "legislatures": {},
        "offices": {},
        "governments": {},
        "government_support": {}
    }
    
    # Track which countries are politically active (first 30 = active, rest = minimal)
    active_countries = set(country_names[:30])
    
    for idx, cname in enumerate(country_names):
        is_active = cname in active_countries
        # Vary number of parties per country (3-5) deterministically
        num_parties = 3 + (idx % 3) if is_active else 0
        
        if not is_active:
            # Minimal country - no political institutions
            continue
        
        # Generate all components
        chars = generate_characters(cname, num_parties)
        parties, party_leaders = generate_parties(cname, idx, num_parties)
        legislature = generate_legislature(cname, parties)
        offices = generate_offices(cname, num_parties)
        governments = generate_governments(cname, parties)
        gov_support = generate_government_support(parties)
        
        # Merge into world
        world["characters"].update(chars)
        world["parties"].update(parties)
        world["legislatures"][f"{cname}_parliament"] = legislature
        world["offices"].update(offices)
        world["governments"].update(governments)
        world["government_support"].update(gov_support)
    
    return world, active_countries, country_names

def generate_institutional_rules(active_countries, all_countries):
    """Generate institutional rules matching the world fixture"""
    institutions = {}
    
    # Base legislature rules template
    base_leg_rules = {
        "confidence_required_to_form": True,
        "formation_support_threshold": 0.5,
        "bill_pass_threshold": 0.5,
        "confidence_pass_threshold": 0.5,
        "no_confidence_removes_government": True,
        "confidence_fail_removes_government": False,
        "proposer_requires_seats": True,
        "government_term_days": 30,
        "term_expiration_causes_election": True,
        "election_call_days": 0
    }
    
    # Base office rules templates
    base_office_president = {
        "appointing_authority": "",
        "dismissible_by": [],
        "is_electoral_authority": True,
        "succession_on_election_loss": True,
        "succession_on_vacancy": "none"
    }
    
    base_office_pm = {
        "appointing_authority": "office_president",
        "dismissible_by": ["office_president"],
        "succession_on_election_loss": True,
        "succession_on_vacancy": "none"
    }
    
    base_office_finance = {
        "appointing_authority": "office_pm",
        "dismissible_by": ["office_president", "office_pm"],
        "succession_on_vacancy": "none"
    }
    
    # Election rules
    base_election_general = {
        "changes_composition": True,
        "changes_head": True,
        "head_office": "office_pm",
        "electoral_authority_office": "office_president",
        "schedulable_independently": True
    }
    
    # Add active countries
    for cname in active_countries:
        # Legislature
        institutions[f"legislature_{cname}_parliament"] = {
            "kind": "legislature",
            "legislature_id": f"{cname}_parliament",
            "rules": base_leg_rules.copy()
        }
        
        # Offices
        institutions[f"office_{cname}_office_president"] = {
            "kind": "office",
            "office_id": f"{cname}_office_president",
            "institution_id": f"{cname}_inst_state",
            "role": "head_of_state",
            "rules": base_office_president.copy()
        }
        
        institutions[f"office_{cname}_office_pm"] = {
            "kind": "office",
            "office_id": f"{cname}_office_pm",
            "institution_id": f"{cname}_inst_government",
            "role": "head_of_government",
            "rules": base_office_pm.copy()
        }
        
        institutions[f"office_{cname}_office_finance"] = {
            "kind": "office",
            "office_id": f"{cname}_office_finance",
            "institution_id": f"{cname}_inst_government",
            "role": "minister",
            "rules": base_office_finance.copy()
        }
    
    # Elections
    elections = {
        "general": {
            "type": "general",
            "scope": "national",
            "rules": base_election_general.copy()
        }
    }
    
    return {
        "_non_final": "TASK-040 benchmark fixture institutional rules - auto-generated to match t040_world.json. NOT production constitutional design.",
        "institutions": institutions,
        "elections": elections
    }

if __name__ == "__main__":
    world, active_countries, all_countries = build_world()
    
    # Write world fixture
    world_path = "C:/tmp/maestro engine/data/worlds/politics/t040_world.json"
    with open(world_path, 'w', encoding='utf-8') as f:
        json.dump(world, f, ensure_ascii=False, indent=1, separators=(',', ': '))
    
    # Write institutional rules fixture
    rules = generate_institutional_rules(active_countries, all_countries)
    rules_path = "C:/tmp/maestro engine/data/rules/t040_institutional_rules.json"
    with open(rules_path, 'w', encoding='utf-8') as f:
        json.dump(rules, f, ensure_ascii=False, indent=1, separators=(',', ': '))
    
    print(f"Generated world fixture: {world_path}")
    print(f"Generated institutional rules: {rules_path}")
    print(f"Active countries: {len(active_countries)}")
    print(f"Total countries: {len(all_countries)}")
    print(f"Characters: {len(world['characters'])}")
    print(f"Parties: {len(world['parties'])}")
    print(f"Legislatures: {len(world['legislatures'])}")
    print(f"Offices: {len(world['offices'])}")
    print(f"Governments: {len(world['governments'])}")