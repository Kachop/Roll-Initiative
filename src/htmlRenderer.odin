package main

import "core:fmt"
import "core:log"
import "core:strings"
import rl "vendor:raylib"

/*
Should take in chunk of html text and figure out how to render the text.
Tags:
<p></p> should add \n
<em></em> italics
<strong></strong> BOLD
*/

Tag :: enum {
    P,
    EM,
    STRONG,
}

TagInfo :: struct {
    type: Tag,
    open: bool,
}

read_tag :: proc(text: string, cursor: ^i32) -> (tag: TagInfo, ok: bool) {
    if text[cursor^] == '<' {
        if text[cursor^+1] == '/' {
            tag.open = false
            cursor^ += 2
        } else {
            tag.open = true
            cursor^ += 1
        }
        start := cursor^
        for text[cursor^] != '>' {
            cursor^ += 1
        }

        tag_name := text[start:cursor^]

        switch tag_name {
        case "p": tag.type = .P; return tag, true
        case "em": tag.type = .EM; return tag, true
        case "strong": tag.type = .STRONG; return tag, true
        case: return tag, false
        }
    }
    return TagInfo{}, false
}

renderHTML :: proc(text: string) -> (result: cstring) {
    cursor : i32 = 0
    start: i32
    end: i32
    tag_pos: i32

    tag: TagInfo
    ok: bool

    append_mode: bool

    char: u8
    for cursor < cast(i32)len(text) {
        char = text[cursor]
        if char == '<' {
            tag_pos = cursor
            tag, ok = read_tag(text, &cursor)
            if ok {
                if tag.open {
                    start = cursor + 1
                    append_mode = true
                } else {
                    end = tag_pos
                    if append_mode {
                        result = fmt.caprint(result, text[start:end], "\n", sep="")
                    }
                    append_mode = false
                }

                if tag.type == .P && tag.open == false {
                    result = fmt.caprint(result, "\n", sep="")
                } else if tag.type == .EM && tag.open == false {
                    result = fmt.caprint(result, "\n", sep="")
                }
            }
        }

        if text[cursor] != '<' {
            if !append_mode && text[cursor] != '>' && text[cursor] != ' ' {
                append_mode = true
                start = cursor
            }
            cursor += 1
        }
    }
    
    sresult := string(result)
    if len(sresult) > 0 {
        if sresult[len(sresult)-1] == '\n' {
            sresult = sresult[:len(sresult)-2]
        }
        result = strings.clone_to_cstring(sresult)
        delete(sresult)
    }
    return result
}
