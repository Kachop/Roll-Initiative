package main

import "core:fmt"
import "core:slice"
import "core:time"
/*
Functionality for logging combats turn by turn in a user readable manner.
Will also output key statistics
*/

Turn :: struct {
	entity:              ^Entity,
	time:                f64,
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
	temp_file:     MD_File,
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
	md_add_text(&logger.log_file, md_h1(state.setup_screen_state.filename_input.text))
	md_newline(&logger.log_file)
	md_underline(&logger.log_file)
	md_add_text(&logger.temp_file, md_h2("Combat log"))
	md_add_text(&logger.temp_file, md_h2("Round ", logger.current_round, ":"))
	context.allocator = static_alloc
}

logger_set_entity :: proc(logger: ^Logger, entity: ^Entity) {
	context.allocator = logger_alloc
	logger.current_turn.entity = entity
	md_add_text(&logger.temp_file, md_h3(entity.alias, "'s turn:"))
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
	md_add_text(
		&logger.temp_file,
		md_bold(entity_from.alias),
		" dealt ",
		md_bold(damage),
		" ",
		md_bold("damage"),
		" to ",
		md_bold(entity_to.alias),
		".",
	)
	md_newline(&logger.temp_file)
	md_add_text(
		&logger.temp_file,
		md_bold(entity_to.alias),
		" has ",
		md_bold(entity_to.HP, "+", entity_to.temp_HP, " hp") if (entity_to.temp_HP > 0) else md_bold(entity_to.HP, " hp"),
		" remaining.",
	)
	if (!entity_to.alive) {
		md_add_text(&logger.temp_file, " ", md_bold(entity_to.alias, " has been slain."))
	}
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_damage_recieved :: proc(logger: ^Logger, damage: int, entity_from: ^Entity) {
	context.allocator = logger_alloc
	logger.current_turn.damage_recieved += damage
	md_add_text(
		&logger.temp_file,
		md_bold(logger.current_turn.entity.alias),
		" was hit for ",
		md_bold(damage, " damage"),
		" by ",
		md_bold(entity_from.alias),
		".",
	)
	md_newline(&logger.temp_file)
	if (logger.current_turn.entity.alive) {
		md_add_text(
			&logger.temp_file,
			md_bold(logger.current_turn.entity.alias),
			" has ",
			md_bold(logger.current_turn.entity.HP, "+", logger.current_turn.entity.temp_HP, " hp") if (logger.current_turn.entity.temp_HP > 0) else md_bold(logger.current_turn.entity.HP, " hp"),
			" remaining",
		)
	} else {
		md_add_text(
			&logger.temp_file,
			md_bold(logger.current_turn.entity.alias, " has dropped to 0 hp"),
			".",
		)
	}
	md_newline(&logger.temp_file)
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
	md_add_text(
		&logger.temp_file,
		md_bold(entity_from.alias),
		" healed ",
		md_bold(entity_to.alias),
		" for ",
		md_bold(healing, " hp"),
		".",
	)
	if (entity_to.HP == cast(i32)healing) {
		md_add_text(&logger.temp_file, md_bold(entity_to.alias), " got up!")
	} else {
		md_newline(&logger.temp_file)
		md_add_text(
			&logger.temp_file,
			md_bold(entity_to.alias),
			" now has ",
			md_bold(entity_to.HP, "+", entity_to.temp_HP, " hp") if (entity_to.temp_HP > 0) else md_bold(entity_to.HP, " hp"),
			".",
		)
	}
	md_newline(&logger.temp_file)
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
	md_add_text(
		&logger.temp_file,
		md_bold(entity_to.alias),
		" was healed for ",
		md_bold(healing, " hp"),
		" by ",
		md_bold(entity_from.alias),
		".",
	)
	if (entity_to.HP == cast(i32)healing) {
		md_add_text(&logger.temp_file, md_bold(entity_to.alias), " got up!")
	} else {
		md_newline(&logger.temp_file)
		md_add_text(
			&logger.temp_file,
			md_bold(entity_to.alias),
			" now has",
			md_bold(entity_to.HP, "+", entity_to.temp_HP, " hp") if (entity_to.temp_HP > 0) else md_bold(entity_to.HP, " hp"),
			".",
		)
	}
	md_newline(&logger.temp_file)
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
	md_add_text(
		&logger.temp_file,
		md_bold(entity_from.alias),
		" gave ",
		md_bold(entity_to.alias),
		" ",
		md_bold(temp_hp, " temp hp"),
		".",
	)
	md_newline(&logger.temp_file)

	md_add_text(
		&logger.temp_file,
		md_bold(entity_to.alias),
		"now has ",
		md_bold(entity_to.HP, "+", entity_to.temp_HP, " hp"),
		".",
	)
	md_newline(&logger.temp_file)
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
	md_add_text(
		&logger.temp_file,
		md_bold(entity_to.alias),
		" got ",
		md_bold(temp_hp, " temp hp"),
		" from ",
		md_bold(entity_from.alias),
		".",
	)
	md_newline(&logger.temp_file)

	md_add_text(
		&logger.temp_file,
		md_bold(entity_to.alias),
		" now has ",
		md_bold(entity_to.HP, "+", entity_to.temp_HP, " hp"),
		".",
	)
	md_newline(&logger.temp_file)
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
	md_add_text(&logger.temp_file, md_bold(entity_to.alias), " was ")

	switch condition {
	case .BLINDED:
		md_add_text(&logger.temp_file, md_bold("blinded"))
	case .CHARMED:
		md_add_text(&logger.temp_file, md_bold("charmed"))
	case .DEAFENED:
		md_add_text(&logger.temp_file, md_bold("deafened"))
	case .FRIGHTENED:
		md_add_text(&logger.temp_file, md_bold("frightened"))
	case .GRAPPLED:
		md_add_text(&logger.temp_file, md_bold("grappled"))
	case .INCAPACITATED:
		md_add_text(&logger.temp_file, md_bold("incapacitated"))
	case .INVISIBLE:
		md_add_text(&logger.temp_file, md_bold("made invisible"))
	case .PARALYZED:
		md_add_text(&logger.temp_file, md_bold("paralyzed"))
	case .PETRIFIED:
		md_add_text(&logger.temp_file, md_bold("petrified"))
	case .POISONED:
		md_add_text(&logger.temp_file, md_bold("poisoned"))
	case .PRONE:
		md_add_text(&logger.temp_file, md_bold("knocked prone"))
	case .RESTRAINED:
		md_add_text(&logger.temp_file, md_bold("restrained"))
	case .STUNNED:
		md_add_text(&logger.temp_file, md_bold("stunned"))
	case .UNCONSCIOUS:
		md_add_text(&logger.temp_file, md_bold("knocked unconscious"))
	case .EXHAUSTION:
		md_add_text(&logger.temp_file, md_bold("given a point of exhaustion"))
	}

	md_add_text(&logger.temp_file, " by ", md_bold(entity_from.alias), ".")
	md_newline(&logger.temp_file)
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
	md_add_text(&logger.temp_file, md_bold(entity_to.alias), " was ")

	switch condition {
	case .BLINDED:
		md_add_text(&logger.temp_file, md_bold("blinded"))
	case .CHARMED:
		md_add_text(&logger.temp_file, md_bold("charmed"))
	case .DEAFENED:
		md_add_text(&logger.temp_file, md_bold("deafened"))
	case .FRIGHTENED:
		md_add_text(&logger.temp_file, md_bold("frightened"))
	case .GRAPPLED:
		md_add_text(&logger.temp_file, md_bold("grappled"))
	case .INCAPACITATED:
		md_add_text(&logger.temp_file, md_bold("incapacitated"))
	case .INVISIBLE:
		md_add_text(&logger.temp_file, md_bold("made invisible"))
	case .PARALYZED:
		md_add_text(&logger.temp_file, md_bold("paralyzed"))
	case .PETRIFIED:
		md_add_text(&logger.temp_file, md_bold("petrified"))
	case .POISONED:
		md_add_text(&logger.temp_file, md_bold("poisoned"))
	case .PRONE:
		md_add_text(&logger.temp_file, md_bold("knocked prone"))
	case .RESTRAINED:
		md_add_text(&logger.temp_file, md_bold("restrained"))
	case .STUNNED:
		md_add_text(&logger.temp_file, md_bold("stunned"))
	case .UNCONSCIOUS:
		md_add_text(&logger.temp_file, md_bold("knocked unconscious"))
	case .EXHAUSTION:
		md_add_text(&logger.temp_file, md_bold("given a point of exhaustion"))
	}

	md_add_text(&logger.temp_file, " by ", md_bold(entity_from.alias), ".")
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_condition_healed :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_text(&logger.temp_file, md_bold(entity_from.alias))

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(
			&logger.temp_file,
			" stopped",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("blinded"),
		)
	case .CHARMED:
		md_add_text(
			&logger.temp_file,
			" ridded ",
			md_bold(entity_to.alias),
			" of being ",
			md_bold("charmed"),
		)
	case .DEAFENED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("deafened"),
		)
	case .FRIGHTENED:
		md_add_text(
			&logger.temp_file,
			" stopped ",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("frightened"),
		)
	case .GRAPPLED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" get out of a ",
			md_bold("grapple"),
		)
	case .INCAPACITATED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("incapacitated"),
		)
	case .INVISIBLE:
		md_add_text(
			&logger.temp_file,
			"helped ",
			md_bold(entity_to.alias),
			" remove ",
			md_bold("invisibility"),
		)
	case .PARALYZED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("paralyzed"),
		)
	case .PETRIFIED:
		md_add_text(
			&logger.temp_file,
			" cured ",
			md_bold(entity_to.alias),
			" from ",
			md_bold("petrification"),
		)
	case .POISONED:
		md_add_text(
			&logger.temp_file,
			" cured ",
			md_bold(entity_to.alias),
			" from being ",
			md_bold("poisoned"),
		)
	case .PRONE:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" up from being ",
			md_bold("prone"),
		)
	case .RESTRAINED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" out of being ",
			md_bold("restrained"),
		)
	case .STUNNED:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" to no longer be ",
			md_bold("stunned"),
		)
	case .UNCONSCIOUS:
		md_add_text(
			&logger.temp_file,
			" helped ",
			md_bold(entity_to.alias),
			" come around from being ",
			md_bold("unconscious"),
		)
	}
	md_add_text(&logger.temp_file, ".")
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_condition_healed_self :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_text(&logger.temp_file, md_bold(entity_to.alias), " was ")

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(&logger.temp_file, " cured from being ", md_bold("blinded"))
	case .CHARMED:
		md_add_text(&logger.temp_file, " helped out of being ", md_bold("charmed"))
	case .DEAFENED:
		md_add_text(&logger.temp_file, " helped out from being ", md_bold("deafened"))
	case .FRIGHTENED:
		md_add_text(&logger.temp_file, " helped out from being ", md_bold("frightened"))
	case .GRAPPLED:
		md_add_text(&logger.temp_file, " helped out of a ", md_bold("grapple"))
	case .INCAPACITATED:
		md_add_text(&logger.temp_file, " helped from being ", md_bold("incapacitated"))
	case .INVISIBLE:
		md_add_text(&logger.temp_file, " made ", md_bold("visible"))
	case .PARALYZED:
		md_add_text(&logger.temp_file, " helped out of ", md_bold("paralysis"))
	case .PETRIFIED:
		md_add_text(&logger.temp_file, " cured of ", md_bold("petrification"))
	case .POISONED:
		md_add_text(&logger.temp_file, " cured of being ", md_bold("poisoned"))
	case .PRONE:
		md_add_text(&logger.temp_file, " helped up from being ", md_bold("prone"))
	case .RESTRAINED:
		md_add_text(&logger.temp_file, " helped out of being ", md_bold("restrained"))
	case .STUNNED:
		md_add_text(&logger.temp_file, " helped out of being ", md_bold("stunned"))
	case .UNCONSCIOUS:
		md_add_text(&logger.temp_file, " helped out of being ", md_bold("unconscious"))
	}

	md_add_text(&logger.temp_file, " by ", md_bold(entity_from.alias))
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_attempt_give_condition :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_text(&logger.temp_file, md_bold(entity_from.alias), " failed to ")

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(&logger.temp_file, md_bold("blind"), " ", md_bold(entity_to.alias))
	case .CHARMED:
		md_add_text(&logger.temp_file, md_bold("charm"), " ", md_bold(entity_to.alias))
	case .DEAFENED:
		md_add_text(&logger.temp_file, md_bold("deafen"), " ", md_bold(entity_to.alias))
	case .FRIGHTENED:
		md_add_text(&logger.temp_file, md_bold("frighten"), " ", md_bold(entity_to.alias))
	case .GRAPPLED:
		md_add_text(&logger.temp_file, md_bold("grapple"), " ", md_bold(entity_to.alias))
	case .INCAPACITATED:
		md_add_text(&logger.temp_file, md_bold("incapacitate"), " ", md_bold(entity_to.alias))
		md_add_text(&logger.temp_file, ", they are immune.")
	case .INVISIBLE:
		md_add_text(&logger.log_file, "make ", md_bold(entity_to.alias), " ", md_bold("invisible"))
	case .PARALYZED:
		md_add_text(&logger.temp_file, md_bold("paralyze"), " ", md_bold(entity_to.alias))
	case .PETRIFIED:
		md_add_text(&logger.temp_file, md_bold("petrify"), " ", md_bold(entity_to.alias))
	case .POISONED:
		md_add_text(&logger.temp_file, md_bold("poison"), " ", md_bold(entity_to.alias))
	case .PRONE:
		md_add_text(&logger.temp_file, "knock ", md_bold(entity_to.alias), " ", md_bold("prone"))
	case .RESTRAINED:
		md_add_text(&logger.temp_file, md_bold("restrain"), " ", md_bold(entity_to.alias))
	case .STUNNED:
		md_add_text(&logger.temp_file, md_bold("stun"), " ", md_bold(entity_to.alias))
	case .UNCONSCIOUS:
		md_add_text(
			&logger.temp_file,
			"knock ",
			md_bold(entity_to.alias),
			" ",
			md_bold("unconscious"),
		)
	}
	md_add_text(&logger.temp_file, ", they are immune.")
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_attempt_recieve_condition :: proc(
	logger: ^Logger,
	condition: Condition,
	entity_from: ^Entity,
	entity_to: ^Entity,
) {
	context.allocator = logger_alloc
	md_add_text(&logger.temp_file, md_bold(entity_to.alias), " avoided being ")

	//Partial switch since nothing other than a rest can remove exhaustion.
	#partial switch condition {
	case .BLINDED:
		md_add_text(&logger.temp_file, md_bold("blinded"), " by ", md_bold(entity_from.alias))
	case .CHARMED:
		md_add_text(&logger.temp_file, md_bold("charmed"), " by ", md_bold(entity_from.alias))
	case .DEAFENED:
		md_add_text(&logger.temp_file, md_bold("deafened"), " by ", md_bold(entity_from.alias))
	case .FRIGHTENED:
		md_add_text(&logger.temp_file, md_bold("frightened"), " by ", md_bold(entity_from.alias))
	case .GRAPPLED:
		md_add_text(&logger.temp_file, md_bold("grappled"), " by ", md_bold(entity_from.alias))
	case .INCAPACITATED:
		md_add_text(
			&logger.temp_file,
			md_bold("incapacitated"),
			" by ",
			md_bold(entity_from.alias),
		)
	case .INVISIBLE:
		md_add_text(
			&logger.temp_file,
			"made ",
			md_bold("invisible"),
			" by ",
			md_bold(entity_from.alias),
		)
	case .PARALYZED:
		md_add_text(&logger.temp_file, md_bold("paralyzed"), " by ", md_bold(entity_from.alias))
	case .PETRIFIED:
		md_add_text(&logger.temp_file, md_bold("petrified"), " by ", md_bold(entity_from.alias))
	case .POISONED:
		md_add_text(&logger.temp_file, md_bold("poisoned"), " by ", md_bold(entity_from.alias))
	case .PRONE:
		md_add_text(
			&logger.temp_file,
			"knocked ",
			md_bold("prone"),
			" by ",
			md_bold(entity_from.alias),
		)
	case .RESTRAINED:
		md_add_text(&logger.temp_file, md_bold("restrained"), " by ", md_bold(entity_from))
	case .STUNNED:
		md_add_text(&logger.temp_file, md_bold("stunned"), " by ", md_bold(entity_from.alias))
	case .UNCONSCIOUS:
		md_add_text(
			&logger.temp_file,
			"knocked ",
			md_bold("unconscious"),
			" by ",
			md_bold(entity_from.alias),
		)
	}
	md_add_text(&logger.temp_file, ", they are immune.")
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_hit_dead :: proc(logger: ^Logger, entity_from: ^Entity, entity_to: ^Entity) {
	context.allocator = logger_alloc
	md_add_text(
		&logger.temp_file,
		md_bold(entity_from.alias),
		" hit ",
		md_bold(entity_to.alias),
		" while they were down. ",
		md_bold("CRIT!"),
	)
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_dead_entity_turn :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	md_add_text(
		&logger.temp_file,
		md_bold(logger.current_turn.entity.alias),
		" has ",
		md_bold("0 hp"),
		". Rolling death save.",
	)
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_turn :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.current_turn.time = time.duration_seconds(
		time.stopwatch_duration(state.combat_screen_state.turn_timer),
	)
	md_add_text(&logger.temp_file, "Turn took ")
	if logger.current_turn.time > 60 {
		minutes := int(
			time.duration_minutes(time.stopwatch_duration(state.combat_screen_state.turn_timer)),
		)
		seconds := logger.current_turn.time - cast(f64)(minutes * 60)
		md_add_text(&logger.temp_file, md_bold(fmt.aprintf("%vm:%.0fs.", minutes, seconds)))
	} else {
		md_add_text(&logger.temp_file, md_bold(fmt.aprintf("%.1fs.", logger.current_turn.time)))
	}
	md_newline(&logger.temp_file)
	append(&logger.round, logger.current_turn)
	logger.current_turn = Turn{}
	context.allocator = static_alloc
}

logger_add_round :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.turns[logger.current_round] = slice.clone(logger.round[:])
	clear(&logger.round)
	logger.current_round += 1
	md_newline(&logger.temp_file)
	md_add_text(&logger.temp_file, md_h2("Round ", logger.current_round, ":"))
	context.allocator = static_alloc
}

logger_end_combat :: proc(logger: ^Logger) {
	context.allocator = logger_alloc
	logger.turns[logger.current_round] = slice.clone(logger.round[:])
	delete(logger.round)

	minutes := int(
		time.duration_minutes(time.stopwatch_duration(state.combat_screen_state.combat_timer)),
	)
	seconds := time.duration_seconds(
		time.stopwatch_duration(state.combat_screen_state.combat_timer),
	)

	md_newline(&logger.temp_file)
	md_add_text(
		&logger.temp_file,
		md_bold("Combat Finished"),
		". Took ",
		md_bold(fmt.aprintf("%vm:%.0fs", minutes, seconds)),
	)
	md_newline(&logger.temp_file)
	context.allocator = static_alloc
}

logger_add_summary :: proc(logger: ^Logger) {
	md_add_text(&logger.log_file, md_h2("Test"))
	md_newline(&logger.log_file)
}

logger_save_to_file :: proc(logger: ^Logger) -> bool {
	md_add_text(&logger.log_file, logger.temp_file.file_string)
	return md_write_file(logger.log_file)
}
