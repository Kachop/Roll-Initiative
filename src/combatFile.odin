package main

import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import "core:fmt"

/*
Custom file format for storing combat information.
Will look something like:

{
    "entity name"
    {
        initiative=val
    },
    "entity name"
    {
        initiative=val
    },
}
*/

CombatFile :: struct {
    name: cstring,
    entities: [dynamic]Entity,
}

CMBT_Token_Kind :: enum u8 {
    CMBT_TOKEN_EOF,
    CMBT_TOKEN_LSQRLY,
    CMBT_TOKEN_RSQRLY,
    CMBT_TOKEN_STRING,
    CMBT_TOKEN_NUMBER,
    CMBT_TOKEN_EQUALS,
    CMBT_TOKEN_FIELD,
    CMBT_TOKEN_COMMA,
}

CMBT_Token :: struct {
    kind: CMBT_Token_Kind,
    value: string,
    position: i32,
}

CMBT_Lexer :: struct {
    buffer: [^]u8,
    buffer_length: i32,
    read_pos: i32,
    pos: i32,
    char: u8,
}

CMBT_lexer_init :: proc(lexer: ^CMBT_Lexer, buffer: [^]u8, len: i32) -> (result: bool) {
    lexer.buffer = buffer
    lexer.buffer_length = len
    lexer.pos = 0
    lexer.read_pos = 0
    lexer.char = 0

    CMBT_lexer_read(lexer)
    result = true
    return
}

CMBT_lexer_peak_ch :: proc(lexer: ^CMBT_Lexer) -> u8 {
    if (lexer.read_pos >= lexer.buffer_length) {
        return cast(u8)CMBT_Token_Kind.CMBT_TOKEN_EOF
    }
    return lexer.buffer[lexer.read_pos]
}

CMBT_lexer_read :: proc(lexer: ^CMBT_Lexer) -> u8 {
    lexer.char = CMBT_lexer_peak_ch(lexer)

    lexer.pos = lexer.read_pos
    lexer.read_pos += 1

    return lexer.char
}

CMBT_lexer_skip_whitespace :: proc(lexer: ^CMBT_Lexer) {
    for isSpace(lexer.char) {
        CMBT_lexer_read(lexer)
    }
}

CMBT_lexer_tokenize_string :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token) -> (result: bool) {
    pos := lexer.pos
    value := [dynamic]rune{}
    
    if (rune(lexer.char) != '"') {
        return false
    }

    CMBT_lexer_read(lexer)

    for (rune(lexer.char) != '"') {
        append(&value, rune(lexer.char))
        CMBT_lexer_read(lexer)
    }

    CMBT_lexer_read(lexer)

    token^ = CMBT_Token{.CMBT_TOKEN_STRING, utf8.runes_to_string(value[:]), pos}
    result = true
    return result
}

CMBT_lexer_tokenize_number :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token) -> (result: bool) {
    pos := lexer.pos
    value := 0
    found_dot := false
    dot_position := 0
    digit := 0
    negative := false

    if !(((48 <= lexer.char) && (lexer.char <= 57)) || (lexer.char == 46) || (lexer.char == 45)) { //check if it's a digit, decimal or minus
        result = false
        return
    }

    if (rune(lexer.char) == '-') {
        negative = true
        CMBT_lexer_read(lexer)
    }

    for (rune(lexer.char) != ',') {
        char_value := 0
        if (rune(lexer.char) == '.') {
            found_dot = true
            dot_position = digit
        } else {
            switch lexer.char {
            case 48:
                char_value = 0
            case 49:
                char_value = 1
            case 50:
                char_value = 2
            case 51:
                char_value = 3
            case 52:
                char_value = 4
            case 53:
                char_value = 5
            case 54:
                char_value = 6
            case 55:
                char_value = 7
            case 56:
                char_value = 8
            case 57:
                char_value = 9
            case:
                result = false
                return
            }
            value_x10 := value * 10
            value = value_x10 + char_value
            digit += 1
        }
        CMBT_lexer_read(lexer)
    }

    if found_dot {
        for _ in 0..<dot_position {
            value /= 10
        }
    }

    if negative {
        value = -value
    }

    CMBT_lexer_read(lexer)

    token^ = CMBT_Token{.CMBT_TOKEN_NUMBER, str(value), pos}
    return true
}

CMBT_lexer_tokenize_field_name :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token) -> (result: bool) {
    pos := lexer.pos

    for (rune(lexer.char) != '=') {
        CMBT_lexer_read(lexer)
    }

    CMBT_lexer_read(lexer)
    result = CMBT_lexer_tokenize_number(lexer, token)

    token^ = CMBT_Token{.CMBT_TOKEN_FIELD, token.value, pos}
    result = true
    return
}

CMBT_parser_parse_fields :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token, combat: ^CombatFile) -> (result: bool) {
    if (!CMBT_lexer_next(lexer, token)) {
        result = false
        return
    }

    if (token.kind == .CMBT_TOKEN_RSQRLY) {
        return true
    }

    for (token.kind != .CMBT_TOKEN_RSQRLY) {
        fmt.println(token.kind, #line)
        if (!CMBT_parser_parse_object(lexer, token, combat)) {
            result = false
            return
        }

        if (!CMBT_lexer_next(lexer, token)) {
            result = false
            return
        }
    }
    result = true
    return
}

CMBT_parser_parse_object :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token, combat: ^CombatFile) -> (result: bool) {

    if (token.kind == .CMBT_TOKEN_STRING) {
        index, ok := match_entity(token.value)
        if ok {
            append(&combat.entities, state.srd_entities[index])
            result = true
        }
    } else if (token.kind == .CMBT_TOKEN_LSQRLY) {
        result = CMBT_parser_parse_fields(lexer, token, combat)
    } else if (token.kind == .CMBT_TOKEN_FIELD) {
        combat.entities[len(combat.entities)-1].initiative = to_i32(token.value)
        result = true
    } else if (token.kind == .CMBT_TOKEN_COMMA) {
        result = true
    }
    return
}

CMBT_lexer_next :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token) -> (result: bool) {
    CMBT_lexer_skip_whitespace(lexer)

    pos := lexer.pos
    switch rune(lexer.char) {
    case '{':
        CMBT_lexer_read(lexer)
        token^ = CMBT_Token{.CMBT_TOKEN_LSQRLY, "", pos}
        result = true
    case '}':
        CMBT_lexer_read(lexer)
        token^ = CMBT_Token{.CMBT_TOKEN_RSQRLY, "", pos}
        result = true
    case '=':
        CMBT_lexer_read(lexer)
        token^ = CMBT_Token{.CMBT_TOKEN_EQUALS, "", pos}
        result = true
    case ',':
        CMBT_lexer_read(lexer)
        token^ = CMBT_Token{.CMBT_TOKEN_COMMA, "", pos}
        result = true
    case '"':
        return CMBT_lexer_tokenize_string(lexer, token)
    case '0'..='9':
        return CMBT_lexer_tokenize_number(lexer, token)
    case '-':
        return CMBT_lexer_tokenize_number(lexer, token)
    case '.':
        return CMBT_lexer_tokenize_number(lexer, token)
    case 'a'..='z':
        return CMBT_lexer_tokenize_field_name(lexer, token)
    case:
        CMBT_lexer_read(lexer)
    }
    result = true
    return
}

CMBT_lexer_peak :: proc(lexer: ^CMBT_Lexer, token: ^CMBT_Token) -> (result: bool) {
    pos := lexer.pos
    read_pos := lexer.read_pos
    char := lexer.char

    result = CMBT_lexer_next(lexer, token)

    lexer.pos = pos
    lexer.read_pos = read_pos
    lexer.char = char
    return
}

CMBT_parse_file :: proc(lexer: ^CMBT_Lexer, combat: ^CombatFile) -> (result: bool) {
    cmbt_token := CMBT_Token{}

    fmt.println("Parsing file...", combat.name)

    if (!CMBT_lexer_next(lexer, &cmbt_token)) {
        result = false
        return
    }

    if (!CMBT_parser_parse_object(lexer, &cmbt_token, combat)) {
        result = false
        return
    }

    fmt.println("Parsed object...")

    if (CMBT_lexer_read(lexer) != cast(u8)CMBT_Token_Kind.CMBT_TOKEN_EOF) {
        result = false
        return
    }
    result = true
    return
}

read_combat_file :: proc(filename: string, setupState: ^SetupScreenState) -> (combat: CombatFile) {
    buffer := rl.LoadFileText(strings.clone_to_cstring(filename))
    lexer := CMBT_Lexer{}
    CMBT_lexer_init(&lexer, buffer, i32(len(cstring(buffer))))
    if CMBT_parse_file(&lexer, &combat) {
        return
    }
    return CombatFile{}
}

writeCombatFile :: proc(filename: string, combat: CombatFile) -> (result: bool) {
    file_string := ""
    line_string: string

    line_string = "{"
    file_string = strings.join([]string{file_string, line_string, "\n"}, "")

    for entity in combat.entities {
        line_string = string(entity.name)
        file_string = strings.join([]string{file_string, "\t\"", line_string, "\"", "\n", "\t", "{\n"}, "")
        file_string = strings.join([]string{file_string, "\t\tinitiative=", str(entity.initiative), ",\n"}, "")
        file_string = strings.join([]string{file_string, "\t},\n"}, "")
    }

    line_string = "}"
    file_string = strings.join([]string{file_string, line_string}, "")

    return rl.SaveFileText(strings.clone_to_cstring(strings.join([]string{state.config.COMBAT_FILES_PATH, filename}, FILE_SEPERATOR)), raw_data(file_string))
}

isSpace :: proc(char: u8) -> bool {
    if char == 20 || char == 9 || char == 13 || char == 10 {
        return true
    } else {
        return false
    }
}
