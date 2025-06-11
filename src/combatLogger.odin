package main

import "core:fmt"
import "core:slice"

/*
Functionality for logging combats turn by turn in a user readable manner.
Will also output key statistics
*/

Turn :: struct {
    entity: ^Entity,

    time               : int,
    damage_dealt       : int,
    damage_recieved    : int,
    healing_done       : int,
    healing_recieved   : int,
    temp_hp_given      : int,
    temp_hp_recieved   : int,
    conditions_applied : int,
    conditions_recieved: int,
}

Logger :: struct {
    log_file  : MD_File,
    stats_file: MD_File,

    current_turn : Turn,
    current_round: int,
    round        : [dynamic]Turn,
    turns        : map[int][]Turn,
}

init_logger :: proc(logger: ^Logger) {
    logger.current_turn  = Turn{}
    logger.current_round = 1
    clear(&logger.round)
    clear(&logger.turns)

    md_init_file(&logger.log_file, fmt.aprint(state.config.COMBAT_FILES_DIR, state.setup_screen_state.filename_input.text, " combat log.md", sep=""))
    md_add_h1(&logger.log_file, string(state.setup_screen_state.filename_input.text))
    md_add_h2(&logger.log_file, fmt.aprint("Round ", logger.current_round, ":", sep=""))

    md_init_file(&logger.stats_file, fmt.aprint(state.config.COMBAT_FILES_DIR, state.setup_screen_state.filename_input.text, " combat stats.md", sep=""))
    md_add_h1(&logger.stats_file, string(state.setup_screen_state.filename_input.text))
}

logger_set_entity :: proc(logger: ^Logger, entity: ^Entity) {
    logger.current_turn.entity = entity
    md_add_h3(&logger.log_file, fmt.aprint(entity.alias, "'s turn:", sep=""))
}

logger_add_damage_dealt :: proc(logger: ^Logger, damage: int, entity_from: ^Entity, entity_to: ^Entity) {
    logger.current_turn.damage_dealt += damage
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" dealt ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(damage, " damage", sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" to ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, ".", sep=""))
    md_newline(&logger.log_file)
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" has ", sep=""))
    if (entity_to.temp_HP > 0) {
        md_add_bold(&logger.log_file, fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, "HP", sep=""))
    } else {
        md_add_bold(&logger.log_file, fmt.aprint(entity_to.HP, " hp", sep=""))
    }
    md_add_text(&logger.log_file, fmt.aprint(" remaining."))
    if (!entity_to.alive) {
        md_add_bold(&logger.log_file, fmt.aprint(" ", entity_to.alias, " has been slain.", sep=""))
    }
    md_newline(&logger.log_file)
}

logger_add_damage_recieved :: proc(logger: ^Logger, damage: int, entity_from: ^Entity) {
    logger.current_turn.damage_recieved += damage
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" was hit for ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(damage, " damage", sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" by ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, ".", sep=""))
    md_newline(&logger.log_file)
    if (logger.current_turn.entity.alive) {
        md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
        md_add_text(&logger.log_file, fmt.aprint(" has", sep=""))
        if (logger.current_turn.entity.temp_HP > 0) {
            md_add_text(&logger.log_file, fmt.aprint(logger.current_turn.entity.HP, "+", logger.current_turn.entity.temp_HP, sep=""))
        } else {
            md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.HP, " hp", sep=""))
        }
        md_add_text(&logger.log_file, fmt.aprint(" remaining."))
    } else {
        md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, " has dropped to 0 hp.", sep=""))
    }
    md_newline(&logger.log_file)
}

logger_add_healing_done :: proc(logger: ^Logger, healing: int, entity_to: Entity) {
    logger.current_turn.healing_done += healing
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep="")) 
    md_add_text(&logger.log_file, fmt.aprint(" healed ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" for ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(healing, " hp.", sep=""))
    if (entity_to.HP == 0) {
        md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
        md_add_text(&logger.log_file, fmt.aprint(" got up!", sep=""))
    }
    md_newline(&logger.log_file)
}

logger_add_healing_recieved :: proc(logger: ^Logger, healing: int, entity_from: Entity) {
    logger.current_turn.healing_recieved += healing
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" was healed for ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(healing, " hp", sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" by ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, ".", sep=""))
    if (logger.current_turn.entity.HP == 0) {
        md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
        md_add_text(&logger.log_file, fmt.aprint(" got up!"))
    }
    md_newline(&logger.log_file)
}

logger_add_temp_hp_given :: proc(logger: ^Logger, temp_hp: int, entity_to: ^Entity) {
    logger.current_turn.temp_hp_given += temp_hp
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep="")) 
    md_add_text(&logger.log_file, fmt.aprint(" gave ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(temp_hp, " temp hp.", sep=""))
    md_newline(&logger.log_file)
}

logger_add_temp_hp_recieved :: proc(logger: ^Logger, temp_hp: int, entity_from: ^Entity) {
    logger.current_turn.temp_hp_recieved += temp_hp
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" got ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(temp_hp, " temp hp", sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" from ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, ".", sep=""))
    md_newline(&logger.log_file)
}

logger_add_condition_applied :: proc(logger: ^Logger, condition: Condition, entity_from: ^Entity, entity_to: ^Entity) {
    logger.current_turn.conditions_applied += 1
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" was ", sep=""))

    switch condition {
    case .BLINDED      : md_add_bold(&logger.log_file, "blinded")
    case .CHARMED      : md_add_bold(&logger.log_file, "charmed")
    case .DEAFENED     : md_add_bold(&logger.log_file, "deafened")
    case .FRIGHTENED   : md_add_bold(&logger.log_file, "frightened")
    case .GRAPPLED     : md_add_bold(&logger.log_file, "grappled")
    case .INCAPACITATED: md_add_bold(&logger.log_file, "incapacitated")
    case .INVISIBLE    : md_add_bold(&logger.log_file, "made invisible")
    case .PARALYZED    : md_add_bold(&logger.log_file, "paralyzed")
    case .PETRIFIED    : md_add_bold(&logger.log_file, "pertified")
    case .POISONED     : md_add_bold(&logger.log_file, "poisoned")
    case .PRONE        : md_add_bold(&logger.log_file, "knocked prone")
    case .RESTRAINED   : md_add_bold(&logger.log_file, "restrained")
    case .STUNNED      : md_add_bold(&logger.log_file, "stunned")
    case .UNCONSCIOUS  : md_add_bold(&logger.log_file, "knocked unconscious")
    case .EXHAUSTION   : md_add_bold(&logger.log_file, "given a point of exhaustion")
    }

    md_add_text(&logger.log_file, " by ")
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep=""))
}

logger_add_condition_recieved :: proc(logger: ^Logger, condition: Condition, entity_from: ^Entity, entity_to: ^Entity) {
    logger.current_turn.conditions_recieved += 1
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" was ", sep=""))

    switch condition {
    case .BLINDED      : md_add_bold(&logger.log_file, "blinded")
    case .CHARMED      : md_add_bold(&logger.log_file, "charmed")
    case .DEAFENED     : md_add_bold(&logger.log_file, "deafened")
    case .FRIGHTENED   : md_add_bold(&logger.log_file, "frightened")
    case .GRAPPLED     : md_add_bold(&logger.log_file, "grappled")
    case .INCAPACITATED: md_add_bold(&logger.log_file, "incapacitated")
    case .INVISIBLE    : md_add_bold(&logger.log_file, "made invisible")
    case .PARALYZED    : md_add_bold(&logger.log_file, "paralyzed")
    case .PETRIFIED    : md_add_bold(&logger.log_file, "pertified")
    case .POISONED     : md_add_bold(&logger.log_file, "poisoned")
    case .PRONE        : md_add_bold(&logger.log_file, "knocked prone")
    case .RESTRAINED   : md_add_bold(&logger.log_file, "restrained")
    case .STUNNED      : md_add_bold(&logger.log_file, "stunned")
    case .UNCONSCIOUS  : md_add_bold(&logger.log_file, "knocked unconscious")
    case .EXHAUSTION   : md_add_bold(&logger.log_file, "given a point of exhaustion")
    }

    md_add_text(&logger.log_file, " by ")
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep=""))
}

logger_add_hit_dead :: proc(logger: ^Logger, entity_from: ^Entity, entity_to: ^Entity) {
    md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" hit ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" while they were down.", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint(" CRIT!"))
    md_newline(&logger.log_file)
}

logger_add_dead_entity_turn :: proc(logger: ^Logger) {
    md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep=""))
    md_add_text(&logger.log_file, fmt.aprint(" has ", sep=""))
    md_add_bold(&logger.log_file, fmt.aprint("0 hp", sep=""))
    md_add_text(&logger.log_file, fmt.aprint(". Rolling death save.", sep=""))
    md_newline(&logger.log_file)
}

logger_add_turn :: proc(logger: ^Logger) {
    append(&logger.round, logger.current_turn)
    logger.current_turn = Turn{}
}

logger_add_round :: proc(logger: ^Logger) {
    logger.turns[logger.current_round] = slice.clone(logger.round[:])
    clear(&logger.round)
    logger.current_round += 1
    md_newline(&logger.log_file)
    md_add_h2(&logger.log_file, fmt.aprint("Round ", logger.current_round, ":", sep=""))
}

logger_end_combat :: proc(logger: ^Logger) {
    logger.turns[logger.current_round] = slice.clone(logger.round[:])
    delete(logger.round)
    md_newline(&logger.log_file)
    md_add_bold(&logger.log_file, "Combat Finished")
    md_newline(&logger.log_file)
}

logger_save_to_file :: proc(logger: ^Logger) -> bool {
    return md_write_file(logger.log_file)
}
