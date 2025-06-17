package main

import "core:fmt"
import "core:slice"

/*
Functionality for logging combats turn by turn in a user readable manner.
Will also output key statistics
*/

Turn :: struct {
	entity:              ^Entity,
	time:                int,
	damage_dealt:        int,
	damage_recieved:     int,
	healing_done:        int,
	healing_recieved:    int,
	temp_hp_given:       int,
	temp_hp_recieved:    int,
	conditions_applied:  int,
	conditions_recieved: int,
}

Logger :: struct {
	log_file:      MD_File,
	stats_file:    MD_File,
	current_turn:  Turn,
	current_round: int,
	round:         [dynamic]Turn,
	turns:         map[int][]Turn,
}

init_logger :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.current_turn = Turn{}
	logger.current_round = 1
	clear(&logger.round)
	clear(&logger.turns)

	md_init_file(
		&logger.log_file,
		fmt.aprint(
			state.config.COMBAT_FILES_DIR,
			state.setup_screen_state.filename_input.text,
			" combat log.md",
			sep = "",
		),
	)
	md_add_h1(&logger.log_file, string(state.setup_screen_state.filename_input.text))
	md_add_h2(&logger.log_file, fmt.aprint("Round ", logger.current_round, ":", sep = ""))

	md_init_file(
		&logger.stats_file,
		fmt.aprint(
			state.config.COMBAT_FILES_DIR,
			state.setup_screen_state.filename_input.text,
			" combat stats.md",
			sep = "",
		),
	)
	md_add_h1(&logger.stats_file, string(state.setup_screen_state.filename_input.text))
	context.allocator = static_alloc
}

logger_set_entity :: proc(logger: ^Logger, entity: ^Entity) {
	context.allocator = logger_alloc
	logger.current_turn.entity = entity
	md_add_h3(
		&logger.log_file,
		fmt.aprint(entity.alias, "'s turn:", sep = "", allocator = logger_alloc),
	)
	context.allocator = static_alloc
}

logger_add_damage_dealt :: proc(
	logger: ^Logger,
	damage: int,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.damage_dealt += damage
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " dealt ")
	md_add_bold(&logger.log_file, fmt.aprint(damage, " damage", sep = ""))
	md_add_text(&logger.log_file, " to ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, ".", sep = ""))
	md_newline(&logger.log_file)
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " has ")
	if (entity_to.temp_HP > 0) {
		md_add_bold(
			&logger.log_file,
			fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, " hp", sep = ""),
		)
	} else {
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.HP, " hp", sep = ""))
	}
	md_add_text(&logger.log_file, " remaining.")
	if (!entity_to.alive) {
		md_add_bold(
			&logger.log_file,
			fmt.aprint(" ", entity_to.alias, " has been slain", sep = ""),
		)
		md_add_text(&logger.log_file, ".")
	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_damage_recieved :: proc(logger: ^Logger, damage: int, entity_from: ^Entity) {
	context.allocator = logger_alloc
	logger.current_turn.damage_recieved += damage
	md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep = ""))
	md_add_text(&logger.log_file, " was hit for ")
	md_add_bold(&logger.log_file, fmt.aprint(damage, " damage", sep = ""))
	md_add_text(&logger.log_file, " by ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, ".", sep = ""))
	md_newline(&logger.log_file)
	if (logger.current_turn.entity.alive) {
		md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep = ""))
		md_add_text(&logger.log_file, " has ")
		if (logger.current_turn.entity.temp_HP > 0) {
			md_add_text(
				&logger.log_file,
				fmt.aprint(
					logger.current_turn.entity.HP,
					"+",
					logger.current_turn.entity.temp_HP,
					" hp",
					sep = "",
				),
			)
		} else {
			md_add_bold(
				&logger.log_file,
				fmt.aprint(logger.current_turn.entity.HP, " hp", sep = ""),
			)
		}
		md_add_text(&logger.log_file, " remaining.")
	} else {
		md_add_bold(
			&logger.log_file,
			fmt.aprint(logger.current_turn.entity.alias, " has dropped to 0 hp", sep = ""),
		)
		md_add_text(&logger.log_file, ".")

	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_healing_done :: proc(
	logger: ^Logger,
	healing: int,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.healing_done += healing
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " healed ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " for ")
	md_add_bold(&logger.log_file, fmt.aprint(healing, " hp", sep = ""))
	md_add_text(&logger.log_file, ".")
	if (entity_to.HP == cast(i32)healing) {
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " got up!")
	} else {
		md_newline(&logger.log_file)
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " now has ")
		if (entity_to.temp_HP > 0) {
			md_add_bold(
				&logger.log_file,
				fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, " hp", sep = ""),
			)
		} else {
			md_add_bold(&logger.log_file, fmt.aprint(entity_to.HP, " hp", sep = ""))
		}
		md_add_text(&logger.log_file, " remaining.")
	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_healing_recieved :: proc(
	logger: ^Logger,
	healing: int,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.healing_recieved += healing
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " was healed for ")
	md_add_bold(&logger.log_file, fmt.aprint(healing, " hp", sep = ""))
	md_add_text(&logger.log_file, " by ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, ".")
	if (entity_to.HP == cast(i32)healing) {
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " got up!")
	} else {
		md_newline(&logger.log_file)
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " now has ")
		if (entity_to.temp_HP > 0) {
			md_add_bold(
				&logger.log_file,
				fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, " hp", sep = ""),
			)
		} else {
			md_add_bold(&logger.log_file, fmt.aprint(entity_to.HP, " hp", sep = ""))
		}
		md_add_text(&logger.log_file, " remaining.")
	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_temp_hp_given :: proc(
	logger: ^Logger,
	temp_hp: int,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.temp_hp_given += temp_hp
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " gave ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " ")
	md_add_bold(&logger.log_file, fmt.aprint(temp_hp, "temp hp", sep = ""))
	md_add_text(&logger.log_file, ".")
	md_newline(&logger.log_file)

	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " now has ")
	md_add_bold(
		&logger.log_file,
		fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, " hp", sep = ""),
	)
	md_add_text(&logger.log_file, "- remaining.")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_temp_hp_recieved :: proc(
	logger: ^Logger,
	temp_hp: int,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.temp_hp_recieved += temp_hp
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " got ")
	md_add_bold(&logger.log_file, fmt.aprint(temp_hp, " temp hp", sep = ""))
	md_add_text(&logger.log_file, " from ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, ".")
	md_newline(&logger.log_file)

	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " now has ")
	md_add_bold(
		&logger.log_file,
		fmt.aprint(entity_to.HP, "+", entity_to.temp_HP, " hp", sep = ""),
	)
	md_add_text(&logger.log_file, "- remaining.")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_condition_applied :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.conditions_applied += 1
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " was ")

	switch condition {
	case .BLINDED:
		md_add_bold(&logger.log_file, "blinded")
	case .CHARMED:
		md_add_bold(&logger.log_file, "charmed")
	case .DEAFENED:
		md_add_bold(&logger.log_file, "deafened")
	case .FRIGHTENED:
		md_add_bold(&logger.log_file, "frightened")
	case .GRAPPLED:
		md_add_bold(&logger.log_file, "grappled")
	case .INCAPACITATED:
		md_add_bold(&logger.log_file, "incapacitated")
	case .INVISIBLE:
		md_add_bold(&logger.log_file, "made invisible")
	case .PARALYZED:
		md_add_bold(&logger.log_file, "paralyzed")
	case .PETRIFIED:
		md_add_bold(&logger.log_file, "petrified")
	case .POISONED:
		md_add_bold(&logger.log_file, "poisoned")
	case .PRONE:
		md_add_bold(&logger.log_file, "knocked prone")
	case .RESTRAINED:
		md_add_bold(&logger.log_file, "restrained")
	case .STUNNED:
		md_add_bold(&logger.log_file, "stunned")
	case .UNCONSCIOUS:
		md_add_bold(&logger.log_file, "knocked unconscious")
	case .EXHAUSTION:
		md_add_bold(&logger.log_file, "given a point of exhaustion")
	}

	md_add_text(&logger.log_file, " by ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, ".")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_condition_recieved :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	logger.current_turn.conditions_recieved += 1
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " was ")

	switch condition {
	case .BLINDED:
		md_add_bold(&logger.log_file, "blinded")
	case .CHARMED:
		md_add_bold(&logger.log_file, "charmed")
	case .DEAFENED:
		md_add_bold(&logger.log_file, "deafened")
	case .FRIGHTENED:
		md_add_bold(&logger.log_file, "frightened")
	case .GRAPPLED:
		md_add_bold(&logger.log_file, "grappled")
	case .INCAPACITATED:
		md_add_bold(&logger.log_file, "incapacitated")
	case .INVISIBLE:
		md_add_bold(&logger.log_file, "made invisible")
	case .PARALYZED:
		md_add_bold(&logger.log_file, "paralyzed")
	case .PETRIFIED:
		md_add_bold(&logger.log_file, "petrified")
	case .POISONED:
		md_add_bold(&logger.log_file, "poisoned")
	case .PRONE:
		md_add_bold(&logger.log_file, "knocked prone")
	case .RESTRAINED:
		md_add_bold(&logger.log_file, "restrained")
	case .STUNNED:
		md_add_bold(&logger.log_file, "stunned")
	case .UNCONSCIOUS:
		md_add_bold(&logger.log_file, "knocked unconscious")
	case .EXHAUSTION:
		md_add_bold(&logger.log_file, "given a point of exhaustion")
	}

	md_add_text(&logger.log_file, " by ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, ".")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_condition_healed :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " helped ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "blinded")
	case .CHARMED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "charmed")
	case .DEAFENED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "deafened")
	case .FRIGHTENED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "frightened")
	case .GRAPPLED:
		md_add_text(&logger.log_file, " get out of ")
		md_add_bold(&logger.log_file, "grappled")
	case .INCAPACITATED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "incapacitated")
	case .INVISIBLE:
		md_add_text(&logger.log_file, " remove ")
		md_add_bold(&logger.log_file, "invisibility")
	case .PARALYZED:
		md_add_text(&logger.log_file, " from being ")
		md_add_bold(&logger.log_file, "paralyzed")
	case .PETRIFIED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "petrified")
	case .POISONED:
		md_add_text(&logger.log_file, " become cured from ")
		md_add_bold(&logger.log_file, "poisoned")
	case .PRONE:
		md_add_text(&logger.log_file, " get up from being ")
		md_add_bold(&logger.log_file, "prone")
	case .RESTRAINED:
		md_add_text(&logger.log_file, " stop being ")
		md_add_bold(&logger.log_file, "restrained")
	case .STUNNED:
		md_add_text(&logger.log_file, " no longer be ")
		md_add_bold(&logger.log_file, "stunned")
	case .UNCONSCIOUS:
		md_add_text(&logger.log_file, " come round from being ")
		md_add_bold(&logger.log_file, "unconscious")
	}
	md_add_text(&logger.log_file, ".")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_condition_healed_self :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, fmt.aprint(" was ", sep = ""))

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(&logger.log_file, " cured from being ")
		md_add_bold(&logger.log_file, "blinded")
	case .CHARMED:
		md_add_text(&logger.log_file, " helped out of being ")
		md_add_bold(&logger.log_file, "charmed")
	case .DEAFENED:
		md_add_text(&logger.log_file, " helped to not be ")
		md_add_bold(&logger.log_file, "deafened")
	case .FRIGHTENED:
		md_add_text(&logger.log_file, " helped from being ")
		md_add_bold(&logger.log_file, "frightened")
	case .GRAPPLED:
		md_add_text(&logger.log_file, " helped out of being ")
		md_add_bold(&logger.log_file, "grappled")
	case .INCAPACITATED:
		md_add_text(&logger.log_file, " helped from being ")
		md_add_bold(&logger.log_file, "incapacitated")
	case .INVISIBLE:
		md_add_text(&logger.log_file, " stoped from being ")
		md_add_bold(&logger.log_file, "invisibility")
	case .PARALYZED:
		md_add_text(&logger.log_file, " helped from being ")
		md_add_bold(&logger.log_file, "paralyzed")
	case .PETRIFIED:
		md_add_text(&logger.log_file, " helped from being ")
		md_add_bold(&logger.log_file, "petrified")
	case .POISONED:
		md_add_text(&logger.log_file, " cured from being ")
		md_add_bold(&logger.log_file, "poisoned")
	case .PRONE:
		md_add_text(&logger.log_file, " got up from being ")
		md_add_bold(&logger.log_file, "prone")
	case .RESTRAINED:
		md_add_text(&logger.log_file, " helped out of being ")
		md_add_bold(&logger.log_file, "restrained")
	case .STUNNED:
		md_add_text(&logger.log_file, " stopped from being ")
		md_add_bold(&logger.log_file, "stunned")
	case .UNCONSCIOUS:
		md_add_text(&logger.log_file, " helped out from being ")
		md_add_bold(&logger.log_file, "unconscious")
	}

	md_add_text(&logger.log_file, " by ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_attempt_give_condition :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " failed to ")

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_bold(&logger.log_file, "blind")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .CHARMED:
		md_add_bold(&logger.log_file, "charm")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .DEAFENED:
		md_add_bold(&logger.log_file, "deafen")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .FRIGHTENED:
		md_add_bold(&logger.log_file, "frighten")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .GRAPPLED:
		md_add_bold(&logger.log_file, "grapple")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .INCAPACITATED:
		md_add_bold(&logger.log_file, "incapacitate")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .INVISIBLE:
		md_add_text(&logger.log_file, "make ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, "invisible ")
		md_add_text(&logger.log_file, ", they are immune.")
	case .PARALYZED:
		md_add_bold(&logger.log_file, "paralyze")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .PETRIFIED:
		md_add_bold(&logger.log_file, "petrify")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .POISONED:
		md_add_bold(&logger.log_file, "poison")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .PRONE:
		md_add_text(&logger.log_file, "knock ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, "prone")
		md_add_text(&logger.log_file, ", they are immune.")
	case .RESTRAINED:
		md_add_bold(&logger.log_file, "restrain")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .STUNNED:
		md_add_bold(&logger.log_file, "stun")
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .UNCONSCIOUS:
		md_add_text(&logger.log_file, "knock ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, " ")
		md_add_bold(&logger.log_file, "unconscious")
		md_add_text(&logger.log_file, ", they are immune.")
	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_attempt_recieve_condition :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " avoided being ")

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_bold(&logger.log_file, "blinded")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .CHARMED:
		md_add_bold(&logger.log_file, "charmed")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .DEAFENED:
		md_add_bold(&logger.log_file, "deafened")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .FRIGHTENED:
		md_add_bold(&logger.log_file, "frightened")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .GRAPPLED:
		md_add_bold(&logger.log_file, "grappled")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .INCAPACITATED:
		md_add_bold(&logger.log_file, "incapacitated")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .INVISIBLE:
		md_add_text(&logger.log_file, "made ")
		md_add_bold(&logger.log_file, "invisible")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .PARALYZED:
		md_add_bold(&logger.log_file, "paralyzed")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .PETRIFIED:
		md_add_bold(&logger.log_file, "petrified")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .POISONED:
		md_add_bold(&logger.log_file, "poisoned")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .PRONE:
		md_add_text(&logger.log_file, "knocked ")
		md_add_bold(&logger.log_file, "prone")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .RESTRAINED:
		md_add_bold(&logger.log_file, "restrained")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .STUNNED:
		md_add_bold(&logger.log_file, "stunned")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	case .UNCONSCIOUS:
		md_add_text(&logger.log_file, "knocked ")
		md_add_bold(&logger.log_file, "unconscious")
		md_add_text(&logger.log_file, " by ")
		md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
		md_add_text(&logger.log_file, ", they are immune.")
	}
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_hit_dead :: proc(logger: ^Logger, entity_from: ^Entity, entity_to: ^Entity) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(entity_from.alias, sep = ""))
	md_add_text(&logger.log_file, " hit ")
	md_add_bold(&logger.log_file, fmt.aprint(entity_to.alias, sep = ""))
	md_add_text(&logger.log_file, " while they were down.")
	md_add_bold(&logger.log_file, fmt.aprint(" CRIT!"))
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_dead_entity_turn :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	md_add_bold(&logger.log_file, fmt.aprint(logger.current_turn.entity.alias, sep = ""))
	md_add_text(&logger.log_file, " has ")
	md_add_bold(&logger.log_file, fmt.aprint("0 hp", sep = ""))
	md_add_text(&logger.log_file, ". Rolling death save.")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_add_turn :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	append(&logger.round, logger.current_turn)
	logger.current_turn = Turn{}
	context.allocator = static_alloc
}

logger_add_round :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.turns[logger.current_round] = slice.clone(logger.round[:])
	clear(&logger.round)
	logger.current_round += 1
	md_newline(&logger.log_file)
	md_add_h2(&logger.log_file, fmt.aprint("Round ", logger.current_round, ":", sep = ""))
	context.allocator = static_alloc
}

logger_end_combat :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.turns[logger.current_round] = slice.clone(logger.round[:])
	delete(logger.round)
	md_newline(&logger.log_file)
	md_add_bold(&logger.log_file, "Combat Finished")
	md_newline(&logger.log_file)
	context.allocator = static_alloc
}

logger_save_to_file :: proc(logger: ^Logger) -> bool {
	return md_write_file(logger.log_file)
}
