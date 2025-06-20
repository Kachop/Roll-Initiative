package main

import "core:fmt"
import rl "vendor:raylib"

MD_File :: struct {
	filename:    string,
	file_string: string,
}

md_init_file :: proc(file: ^MD_File, filename: string) {
	file.filename = filename
}

md_add_text :: #force_inline proc(file: ^MD_File, text: ..any) {
	file.file_string = fmt.aprint(file.file_string, text, sep = "")
}

md_h1 :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint("# ", text, sep = "")
}

md_h2 :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint("## ", text, sep = "")
}

md_h3 :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint("### ", text, sep = "")
}

md_indent :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint(">", text, sep = "")
}

md_bold :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint("**", text, "**", sep = "")
}

md_italic :: #force_inline proc(text: ..any) -> string {
	return fmt.aprint("*", text, "*", sep = "")
}

md_underline :: #force_inline proc(file: ^MD_File) {
	file.file_string = fmt.aprint(file.file_string, "___", sep = "")
	md_newline(file)
}

md_tab :: proc(file: ^MD_File) {
	file.file_string = fmt.aprint(file.file_string, "\t", sep = "")
}

md_newline :: proc(file: ^MD_File) {
	file.file_string = fmt.aprint(file.file_string, "\n", sep = "")
}

md_write_file :: proc(file: MD_File) -> bool {
	return rl.SaveFileText(cstr(file.filename), raw_data(file.file_string))
}
