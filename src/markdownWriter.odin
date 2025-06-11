package main

import "core:fmt"
import rl "vendor:raylib"

MD_File :: struct {
    filename   : string,
    file_string: string,
}

md_init_file :: proc(file: ^MD_File, filename: string) {
    file.filename = filename
}

md_add_h1 :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, "# ", text, sep="")
    md_newline(file)
}

md_add_h2 :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, "## ", text, sep="")
    md_newline(file)
}

md_add_h3 :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, "### ", text, sep="")
    md_newline(file)
}

md_add_indent :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, ">", text, sep="")
    md_newline(file)
}

md_add_text :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, text, sep="")
}

md_add_bold :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, "**", text, "**", sep="")
}

md_add_italic :: proc(file: ^MD_File, text: string) {
    file.file_string = fmt.aprint(file.file_string, "*", text, "*", sep="")
}

md_tab :: proc(file: ^MD_File) {
    file.file_string = fmt.aprint(file.file_string, "\t", sep="")
}

md_newline :: proc(file: ^MD_File) {
    file.file_string = fmt.aprint(file.file_string, "\n", sep="")
}

md_write_file :: proc(file: MD_File) -> bool {
    return rl.SaveFileText(cstr(file.filename), raw_data(file.file_string))
}
