package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:encoding/json"
import "core:strings"
import "core:math/rand"
import rl "vendor:raylib"

/*
File to contain all information and functionality surrounding entities.
Data structure for entities.
Loading entities from file.
*/

EntityType :: enum {
  PLAYER,
  MONSTER,
  NPC,
}

EntitySize :: enum {
  tiny,
  small,
  medium,
  large,
  huge,
  gargantuan,
}

DamageType :: enum {
  ANY,
  SLASHING,
  PIERCING,
  BLUDGEONING,
  NON_MAGICAL,
  POISON,
  ACID,
  FIRE,
  COLD,
  RADIANT,
  NECROTIC,
  LIGHTNING,
  THUNDER,
  FORCE,
  PSYCHIC,
}

Condition :: enum {
  BLINDED,
  CHARMED,
  DEAFENED,
  FRIGHTENED,
  GRAPPLED,
  INCAPACITATED,
  INVISIBLE,
  PARALYZED,
  PETRIFIED,
  POISONED,
  PRONE,
  RESTRAINED,
  STUNNED,
  UNCONSCIOUS,
  EXHAUSTION,
}

DamageSet :: bit_set[DamageType]

ConditionSet :: bit_set[Condition]

Entity :: struct {
  name: cstring,
  alias: cstring,
  race: cstring,
  size: cstring,
  type: EntityType,
  initiative: i32,
  AC: i32,
  HP_max: i32,
  HP: i32,
  temp_HP: i32,
  conditions: ConditionSet,
  visible: bool,
  alive: bool,
  speed: cstring,
  STR: i32,
  STR_mod: i32,
  STR_save: i32,
  DEX: i32,
  DEX_mod: i32,
  DEX_save: i32,
  CON: i32,
  CON_mod: i32,
  CON_save: i32,
  INT: i32,
  INT_mod: i32,
  INT_save: i32,
  WIS: i32,
  WIS_mod: i32,
  WIS_save: i32,
  CHA: i32,
  CHA_mod: i32,
  CHA_save: i32,
  skills: cstring,
  dmg_vulnerabilities: DamageSet,
  temp_dmg_vulnerabilities: DamageSet,
  dmg_resistances: DamageSet,
  temp_dmg_resistances: DamageSet,
  dmg_immunities: DamageSet,
  temp_dmg_immunities: DamageSet,
  condition_immunities: ConditionSet,
  senses: cstring,
  languages: cstring,
  CR: cstring,
  traits: cstring,
  actions: cstring,
  legendary_actions: cstring,
  img_url: cstring,
  img_border: cstring,
  icon_data: string,
}

load_entities_from_file :: proc(filename: string) -> #soa[dynamic]Entity {
  entities: #soa[dynamic]Entity
  log.debugf("LOADING FILE: %v", filename)
  file_data, ok :=  os.read_entire_file(filename)
  if (ok) {
    json_data, err := json.parse(file_data)
    //Loop over the entities and fill the struct.
    if err == .None {
      for entity in json_data.(json.Array) {
        entity_fields := entity.(json.Object)
        
        entity_type: EntityType
        switch entity_fields["Type"].(string) {
        case "player":
          entity_type = .PLAYER
        case "NPC":
          entity_type = .NPC
        case "monster":
          entity_type = .MONSTER
        }

        icon_data: string

        if (("img_url" in entity_fields) && ("img_border" in entity_fields)) {
          _, icon_data = get_entity_icon_data(cstr(entity_fields["img_url"].(string)), cstr(entity_fields["img_border"].(string)))
        }

        new_entity := Entity{
          fmt.caprint(entity_fields["Name"].(string)),
          fmt.caprint(entity_fields["Name"].(string)),
          fmt.caprint(entity_fields["Race"].(string)),
          fmt.caprint(entity_fields["Size"].(string)),
          entity_type,
          i32(0),
          cast(i32)entity_fields["Armour Class"].(f64),
          cast(i32)entity_fields["Hit Points Max"].(f64) if ("Hit Points Max" in entity_fields) else cast(i32)entity_fields["Hit Points"].(f64),
          cast(i32)entity_fields["Hit Points"].(f64),
          cast(i32)entity_fields["Temp Hit Points"].(f64) if ("Temp Hit Points" in entity_fields) else 0,
          get_conditions(entity_fields["Conditions"].(json.Array)[:]) if ("Conditions" in entity_fields) else {},
          true,
          true,
          fmt.caprint(entity_fields["Speed"].(string)),
          cast(i32)entity_fields["STR"].(f64),
          cast(i32)entity_fields["STR_mod"].(f64),
          cast(i32)entity_fields["STR_save"].(f64),
          cast(i32)entity_fields["DEX"].(f64),
          cast(i32)entity_fields["DEX_mod"].(f64),
          cast(i32)entity_fields["DEX_save"].(f64),
          cast(i32)entity_fields["CON"].(f64),
          cast(i32)entity_fields["CON_mod"].(f64),
          cast(i32)entity_fields["CON_save"].(f64),
          cast(i32)entity_fields["INT"].(f64),
          cast(i32)entity_fields["INT_mod"].(f64),
          cast(i32)entity_fields["INT_save"].(f64),
          cast(i32)entity_fields["WIS"].(f64),
          cast(i32)entity_fields["WIS_mod"].(f64),
          cast(i32)entity_fields["WIS_save"].(f64),
          cast(i32)entity_fields["CHA"].(f64),
          cast(i32)entity_fields["CHA_mod"].(f64),
          cast(i32)entity_fields["CHA_save"].(f64),
          fmt.caprint(entity_fields["Skills"].(string)) if ("Skills" in entity_fields) else "",
          get_vulnerabilities_resistances_or_immunities(entity_fields["Damage Vulnerabilities"].(json.Array)[:]) if ("Damage Vulnerabilities" in entity_fields) else {},
          {},
          get_vulnerabilities_resistances_or_immunities(entity_fields["Damage Resistances"].(json.Array)[:]) if ("Damage Resistances" in entity_fields) else {},
          {},
          get_vulnerabilities_resistances_or_immunities(entity_fields["Damage Immunities"].(json.Array)[:]) if ("Damage Immunities" in entity_fields) else {},
          {},
          get_conditions(entity_fields["Condition Immunities"].(json.Array)[:]) if ("Condition Immunities" in entity_fields) else {},
          fmt.caprint(entity_fields["Senses"].(string)) if ("Senses" in entity_fields) else "",
          fmt.caprint(entity_fields["Languages"].(string)) if ("Languages" in entity_fields) else "",
          fmt.caprint(entity_fields["Challenge"].(string)) if ("Challenge" in entity_fields) else "",
          renderHTML(entity_fields["Traits"].(string)) if ("Traits" in entity_fields) else "",
          renderHTML(entity_fields["Actions"].(string)) if ("Actions" in entity_fields) else "",
          renderHTML(entity_fields["Legendary Actions"].(string)) if ("Legendary Actions" in entity_fields) else "",
          fmt.caprint(entity_fields["img_url"].(string)) if ("img_url" in entity_fields) else "",
          fmt.caprint(entity_fields["img_border"].(string)) if ("img_border" in entity_fields) else "",
          icon_data,
        }
        append_soa(&entities, new_entity)
      }
    }
  }
  return entities
}

add_entity_to_file :: proc(entity: Entity, filename: string = state.config.CUSTOM_ENTITY_FILE_PATH, wipe: bool = false) {
    log.debugf("Adding %v to %v", entity.name, filename)
    file_data, ok := os.read_entire_file(filename)
    file_string := string(file_data)
    
    if wipe {
        file_string = ""
    }

    if (len(file_string) > 3) {
        char := rune(file_string[len(file_string)-1])
        for char != rune('}') {
            file_string = file_string[:len(file_string)-1]
            char = rune(file_string[len(file_string)-1])
        }
    } else {
        file_string = ""
        file_string = fmt.tprint(file_string, "[\n\t{\n\t\t", sep="")
    }
    
    if (ok) {
        if len(file_string) > 7 {
            file_string = fmt.tprint(file_string, ",\n\t{\n\t\t", sep="")
        }
        file_string = fmt.tprintf("%v\"Name\": \"%v\",\n\t\t", file_string, entity.name)
        file_string = fmt.tprintf("%v\"Race\": \"%v\",\n\t\t", file_string, entity.race)
        file_string = fmt.tprintf("%v\"Size\": \"%v\",\n\t\t", file_string, entity.size)

        entity_type:  string
        switch entity.type {
        case .PLAYER: entity_type = "player"
        case .NPC: entity_type = "NPC"
        case .MONSTER: entity_type = "monster"
        case: entity_type = ""
        }

        file_string = fmt.tprintf("%v\"Type\": \"%v\",\n\t\t", file_string, entity_type)
        file_string = fmt.tprintf("%v\"Armour Class\": %v,\n\t\t", file_string, entity.AC)
        file_string = fmt.tprintf("%v\"Hit Points\": %v,\n\t\t", file_string, entity.HP)

        if entity.type == .PLAYER {
            file_string = fmt.tprintf("%v\"Hit Points Max\": %v,\n\t\t", file_string, entity.HP_max)
            file_string = fmt.tprintf("%v\"Temp Hit Points\": %v,\n\t\t", file_string, entity.temp_HP)
        }

        conditions_string := fmt.tprint(gen_condition_string(entity.conditions), sep="")
        file_string = fmt.tprintf("%v\"Conditions\": %v,\n\t\t", file_string, conditions_string)

        file_string = fmt.tprintf("%v\"Speed\": \"%v\",\n\t\t", file_string, entity.speed)
        file_string = fmt.tprintf("%v\"STR\": %v,\n\t\t", file_string, entity.STR)
        file_string = fmt.tprintf("%v\"STR_mod\": %v,\n\t\t", file_string, entity.STR_mod)
        file_string = fmt.tprintf("%v\"STR_save\": %v,\n\t\t", file_string, entity.STR_save)
        file_string = fmt.tprintf("%v\"DEX\": %v,\n\t\t", file_string, entity.DEX)
        file_string = fmt.tprintf("%v\"DEX_mod\": %v,\n\t\t", file_string, entity.DEX_mod)
        file_string = fmt.tprintf("%v\"DEX_save\": %v,\n\t\t", file_string, entity.DEX_save)
        file_string = fmt.tprintf("%v\"CON\": %v,\n\t\t", file_string, entity.CON)
        file_string = fmt.tprintf("%v\"CON_mod\": %v,\n\t\t", file_string, entity.CON_mod)
        file_string = fmt.tprintf("%v\"CON_save\": %v,\n\t\t", file_string, entity.CON_save)
        file_string = fmt.tprintf("%v\"INT\": %v,\n\t\t", file_string, entity.INT)
        file_string = fmt.tprintf("%v\"INT_mod\": %v,\n\t\t", file_string, entity.INT_mod)
        file_string = fmt.tprintf("%v\"INT_save\": %v,\n\t\t", file_string, entity.INT_save)
        file_string = fmt.tprintf("%v\"WIS\": %v,\n\t\t", file_string, entity.WIS)
        file_string = fmt.tprintf("%v\"WIS_mod\": %v,\n\t\t", file_string, entity.WIS_mod)
        file_string = fmt.tprintf("%v\"WIS_save\": %v,\n\t\t", file_string, entity.WIS_save)
        file_string = fmt.tprintf("%v\"CHA\": %v,\n\t\t", file_string, entity.CHA)
        file_string = fmt.tprintf("%v\"CHA_mod\": %v,\n\t\t", file_string, entity.CHA_mod)
        file_string = fmt.tprintf("%v\"CHA_save\": %v,\n\t\t", file_string, entity.CHA_save)
        file_string = fmt.tprintf("%v\"Skills\": \"%v\",\n\t\t", file_string, entity.skills)

        vulnerabilities_string := fmt.tprint(gen_vulnerability_resistance_or_immunity_string(entity.dmg_vulnerabilities), sep=", ")
        file_string = fmt.tprintf("%v\"Damage Vulnerabilities\": %v,\n\t\t", file_string, vulnerabilities_string)

        resistance_string := fmt.tprint(gen_vulnerability_resistance_or_immunity_string(entity.dmg_resistances), sep=", ")
        file_string = fmt.tprintf("%v\"Damage Resistances\": %v,\n\t\t", file_string, resistance_string)

        immunity_string := fmt.tprint(gen_vulnerability_resistance_or_immunity_string(entity.dmg_immunities), sep=", ")
        file_string = fmt.tprintf("%v\"Damage Immunities\": %v,\n\t\t", file_string, immunity_string)

        conditions_string = fmt.tprint(gen_condition_string(entity.condition_immunities), sep=", ")
        file_string = fmt.tprintf("%v\"Condition Immunities\": %v,\n\t\t", file_string, conditions_string)
        file_string = fmt.tprintf("%v\"Senses\": \"%v\",\n\t\t", file_string, entity.senses)
        file_string = fmt.tprintf("%v\"Languages\": \"%v\",\n\t\t", file_string, entity.languages)

        if entity.type == .MONSTER {
            file_string = fmt.tprintf("%v\"Challenge\": \"%v\",\n\t\t", file_string, entity.CR)
            file_string = fmt.tprintf("%v\"Traits\": \"%v\",\n\t\t", file_string, entity.traits)
            file_string = fmt.tprintf("%v\"Actions\": \"%v\",\n\t\t", file_string, entity.actions)
            file_string = fmt.tprintf("%v\"Legendary Actions\": \"%v\",\n\t\t", entity.legendary_actions)
        }

        file_string = fmt.tprintf("%v\"img_url\": \"%v\",\n\t\t", file_string, entity.img_url)
        file_string = fmt.tprintf("%v\"img_border\": \"%v\"", file_string, entity.img_border)
        file_string = fmt.tprint(file_string, "\n\t}\n]", sep="")
    }
    rl.SaveFileText(fmt.ctprint(filename), raw_data(file_string))
}

get_entity_type :: proc(type: string) -> (result: EntityType) {
    switch type {
    case "player": result = .PLAYER
    case "NPC": result = .NPC
    case: result = .MONSTER
    }
    return result
}

get_modifier :: proc(score: i32) -> (result: i32) {
    switch {
    case 0 <= score && score <= 9: result = (score - 11) / 2
    case score >= 11: result = (score - 10) / 2
    }
    return
}

get_vulnerabilities_resistances_or_immunities :: proc{get_vulnerabilities_resistances_or_immunities_string, get_vulnerabilities_resistances_or_immunities_json}

get_vulnerabilities_resistances_or_immunities_string :: proc(resistances: []string) -> (result: DamageSet) {
  for resistance in resistances {
    switch strings.to_lower(resistance, allocator=context.temp_allocator) {
    case "slashing": result |= {.SLASHING}
    case "piercing": result |= {.PIERCING}
    case "bludgeoning": result |= {.BLUDGEONING}
    case "poison": result |= {.POISON}
    case "acid": result |= {.ACID}
    case "fire": result |= {.FIRE}
    case "cold": result |= {.COLD}
    case "radiant": result |= {.RADIANT}
    case "necrotic": result |= {.NECROTIC}
    case "lightning": result |= {.LIGHTNING}
    case "thunder": result |= {.THUNDER}
    case "force": result |= {.FORCE}
    case "psychic": result |= {.PSYCHIC}
    case: continue
    }
  }
  return
}

get_vulnerabilities_resistances_or_immunities_json :: proc (resistances: []json.Value) -> (result: DamageSet) {
  for resistance in resistances {
    switch strings.to_lower(resistance.(string), allocator=context.temp_allocator) {
    case "slashing": result |= {.SLASHING}
    case "piercing": result |= {.PIERCING}
    case "bludgeoning": result |= {.BLUDGEONING}
    case "poison": result |= {.POISON}
    case "acid": result |= {.ACID}
    case "fire": result |= {.FIRE}
    case "cold": result |= {.COLD}
    case "radiant": result |= {.RADIANT}
    case "necrotic": result |= {.NECROTIC}
    case "lightning": result |= {.LIGHTNING}
    case "thunder": result |= {.THUNDER}
    case "force": result |= {.FORCE}
    case "psychic": result |= {.PSYCHIC}
    case: continue
    }
  }
  return
}

gen_vulnerability_resistance_or_immunity_string :: proc(values: DamageSet) -> (result: []string) {
  temp_list: [dynamic]string
  //defer delete(temp_list)
  types := []DamageType{.SLASHING, .PIERCING, .BLUDGEONING, .NON_MAGICAL, .POISON, .ACID, .FIRE, .COLD, .RADIANT, .NECROTIC, .LIGHTNING, .THUNDER, .FORCE, .PSYCHIC}
  //defer delete(types)

  for type in types {
    switch type {
    case .ANY:
    case .SLASHING: if .SLASHING in values {append(&temp_list, "Slashing")}
    case .PIERCING: if .PIERCING in values {append(&temp_list, "Piercing")}
    case .BLUDGEONING: if .BLUDGEONING in values {append(&temp_list, "Bludgeoning")}
    case .NON_MAGICAL: if .NON_MAGICAL in values {append(&temp_list, "Non-magical attacks")}
    case .POISON: if .POISON in values {append(&temp_list, "Poison")}
    case .ACID: if .ACID in values {append(&temp_list, "Acid")}
    case .FIRE: if .FIRE in values {append(&temp_list, "Fire")}
    case .COLD: if .COLD in values {append(&temp_list, "Cold")}
    case .RADIANT: if .RADIANT in values {append(&temp_list, "Radiant")}
    case .NECROTIC: if .NECROTIC in values {append(&temp_list, "Necrotic")}
    case .LIGHTNING: if .LIGHTNING in values {append(&temp_list, "Lightning")}
    case .THUNDER: if .THUNDER in values {append(&temp_list, "Thunder")}
    case .FORCE: if .FORCE in values {append(&temp_list, "Force")}
    case .PSYCHIC: if .PSYCHIC in values {append(&temp_list, "Psychic")}
    }
  }
  result = temp_list[:]
  return
}

get_conditions :: proc{get_conditions_string, get_conditions_json}

get_conditions_string :: proc(immunities: []string) -> (result: ConditionSet) {
  for immunity in immunities {
    switch strings.to_lower(immunity, allocator=context.temp_allocator) {
    case "blinded": result |= {.BLINDED}
    case "charmed": result |= {.CHARMED}
    case "deafened": result |= {.DEAFENED}
    case "frightened": result |= {.FRIGHTENED}
    case "grappled": result |= {.GRAPPLED}
    case "incapacitated": result |= {.INCAPACITATED}
    case "invisible": result |= {.INVISIBLE}
    case "paralyzed": result |= {.PARALYZED}
    case "petrified": result |= {.PETRIFIED}
    case "poisoned": result |= {.POISONED}
    case "prone": result |= {.PRONE}
    case "restrained": result |= {.RESTRAINED}
    case "stunned": result |= {.STUNNED}
    case "unconscious": result |= {.UNCONSCIOUS}
    case "exhaustion": result |= {.EXHAUSTION}
    case: continue
    }
  }
  return
}

get_conditions_json :: proc(immunities: []json.Value) -> (result: ConditionSet) {
  for immunity in immunities {
    switch strings.to_lower(immunity.(string), allocator=context.temp_allocator) {
    case "blinded": result |= {.BLINDED}
    case "charmed": result |= {.CHARMED}
    case "deafened": result |= {.DEAFENED}
    case "frightened": result |= {.FRIGHTENED}
    case "grappled": result |= {.GRAPPLED}
    case "incapacitated": result |= {.INCAPACITATED}
    case "invisible": result |= {.INVISIBLE}
    case "paralyzed": result |= {.PARALYZED}
    case "petrified": result |= {.PETRIFIED}
    case "poisoned": result |= {.POISONED}
    case "prone": result |= {.PRONE}
    case "restrained": result |= {.RESTRAINED}
    case "stunned": result |= {.STUNNED}
    case "unconscious": result |= {.UNCONSCIOUS}
    case "exhaustion": result |= {.EXHAUSTION}
    case: continue
    }
  }
  return
}

gen_condition_string :: proc(values: ConditionSet) -> (result: []string) {
  temp_list: [dynamic]string
  //defer delete(temp_list)
  types := []Condition{.BLINDED, .CHARMED, .DEAFENED, .FRIGHTENED, .GRAPPLED, .INCAPACITATED, .INVISIBLE, .PARALYZED, .PETRIFIED, .POISONED, .PRONE, .RESTRAINED, .STUNNED, .UNCONSCIOUS, .EXHAUSTION}
  //defer delete(types)

  for type in types {
    switch type {
    case .BLINDED: if .BLINDED in values {append(&temp_list, "Blinded")}
    case .CHARMED: if .CHARMED in values {append(&temp_list, "Charmed")}
    case .DEAFENED: if .DEAFENED in values {append(&temp_list, "Deafened")}
    case .FRIGHTENED: if .FRIGHTENED in values {append(&temp_list, "Frightened")}
    case .GRAPPLED: if .GRAPPLED in values {append(&temp_list, "Grappled")}
    case .INCAPACITATED: if .INCAPACITATED in values {append(&temp_list, "Incapacitated")}
    case .INVISIBLE: if .INVISIBLE in values {append(&temp_list, "Invisible")}
    case .PARALYZED: if .PARALYZED in values {append(&temp_list, "Paralyzed")}
    case .PETRIFIED: if .PETRIFIED in values {append(&temp_list, "Petrified")}
    case .POISONED: if .POISONED in values {append(&temp_list, "Poisoned")}
    case .PRONE: if .PRONE in values {append(&temp_list, "Prone")}
    case .RESTRAINED: if .RESTRAINED in values {append(&temp_list, "Restrained")}
    case .STUNNED: if .STUNNED in values {append(&temp_list, "Stunned")}
    case .UNCONSCIOUS: if .UNCONSCIOUS in values {append(&temp_list, "Unconscious")}
    case .EXHAUSTION: if .EXHAUSTION in values {append(&temp_list, "Exhaustion")}
    }
  }
  result = temp_list[:]
  return
}

entity_roll_initiative :: proc(entity: ^Entity) {
  //Roll entity initiative using dex score.
  d20 := cast(i32)rand.int_max(20)
  entity.initiative = d20 + entity.DEX_mod
}

is_entity_dead :: proc(entity: ^Entity) {
  //Check if current HP is below 0, if so set HP to 0 and set entity to dead
  if (entity.HP <= 0) {
    entity.HP = 0
    entity.alive = false
  } else {
    entity.alive = true
  }
}

is_entity_over_max :: proc(entity: ^Entity) {
    if (entity.HP > entity.HP_max) {
        entity.HP = entity.HP_max
        entity.alive = true
    } else {
        entity.alive = true
    }
}

entity_toggle_visible :: proc(entity: ^Entity) {
  entity.visible = !entity.visible
  return
}
