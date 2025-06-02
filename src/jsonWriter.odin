package main

import "core:fmt"
import "core:log"
import "core:strings"
import rl "vendor:raylib"

Integer :: i64
Float   :: f64
Boolean :: bool
String  :: string
Array   :: distinct map[string]Value
Object  :: distinct map[string]Value

Value :: union {
    Integer,
    Float,
    Boolean,
    String,
    Array,
    Object,
}

JSONFile :: struct {
    filename    : string,
    json_string : string,
    indent_level: i32,
}

init_file :: proc(filename: string) -> JSONFile {
    return JSONFile {
        filename,
        "",
        0,
    }
}

add_int :: proc(name: string, val: Integer, file: ^JSONFile) {
    add_indent(file)
    file.json_string = str(
        file.json_string,
        "\"", name, "\": ",
        val, ",\n",
        sep="")
}

add_float :: proc(name: string, val: Float, file: ^JSONFile) {
    add_indent(file)
    file.json_string = str(
        file.json_string,
        "\"", name, "\": ",
        val, ",\n",
        sep="")
}

add_bool :: proc(name: string, val: bool, file: ^JSONFile) {
    add_indent(file)
    file.json_string = str(
        file.json_string,
        "\"", name, "\": ",
        "true" if val else "false", ",\n",
        sep="")
}

add_string :: proc(name: string, val: string, file: ^JSONFile) {
    add_indent(file)
    file.json_string = str (
        file.json_string,
        "\"", name, "\": ",
        "\"", val, "\",\n",
        sep="")
}

add_array :: proc(name: string, vals: Array, file: ^JSONFile) {
    add_indent(file)
    if name != "" {
        file.json_string = str(
            file.json_string,
            "\"", name, "\": [\n",
            sep="")
    } else {
        file.json_string = str(
            file.json_string,
            "[\n",
            sep="")
    }
    file.indent_level += 1

    for name, val in vals {
        add_indent(file)
        switch t in val {
        case Integer: add_int(name, val.(Integer), file)
        case Float  : add_float(name, val.(Float), file)
        case Boolean: add_bool(name, val.(Boolean), file)
        case String : add_string(name, val.(String), file)
        case Array  : add_array(name, val.(Array), file)
        case Object : add_object(name, val.(Object), file)
        }
    }
    file.indent_level -= 1
    add_indent(file)
    file.json_string = str(
        file.json_string,
        "],\n",
        sep="")
}

add_object :: proc(name: string, fields: Object, file: ^JSONFile) {
    add_indent(file)
    log.debugf("indent: %v", file.indent_level)
    if name != "" {
        file.json_string = str(
            file.json_string,
            "\"", name, "\": {\n",
            sep="")
    } else {
        file.json_string = str(
            file.json_string,
            "{\n",
            sep="")
    }
    file.indent_level += 1

    for name, val in fields {
        add_indent(file)
        switch t in val {
        case Integer: add_int(name, val.(Integer), file)
        case Float  : add_float(name, val.(Float), file)
        case Boolean: add_bool(name, val.(Boolean), file)
        case String : add_string(name, val.(String), file)
        case Array  : add_array(name, val.(Array), file)
        case Object : add_object(name, val.(Object), file)
        }
    }
    file.indent_level -= 1
    add_indent(file)
    file.json_string = str(
        file.json_string,
        "},\n",
        sep="")
}

add_indent :: proc(file: ^JSONFile) {
    for _ in 0..<file.indent_level {
        file.json_string = str(
        file.json_string,
        "\t",
        sep="")
    }
}

write :: proc(filename: string, file: JSONFile) -> bool {
    return rl.SaveFileText(fmt.ctprint(filename), raw_data(file.json_string))
}
