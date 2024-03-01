const Tokenizer = @This();
const std = @import("std");

idx: u32 = 0,

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Tag = enum {
        invalid,
        root_kw,
        enum_kw,
        struct_kw,
        map_kw,
        any_kw,
        unknown_kw,
        pipe,
        comma,
        eq,
        colon,
        at,
        lb,
        rb,
        lsb,
        rsb,
        qmark,
        identifier,
        doc_comment_line,
        bytes,
        int,
        float,
        bool,
        eof,

        // never generated by the tokenizer but
        // used elsewhere
        expr,
        tag_name,

        pub fn lexeme(self: Tag) []const u8 {
            return switch (self) {
                .invalid => "(invalid)",
                .root_kw => "root",
                .enum_kw => "enum",
                .struct_kw => "struct",
                .map_kw => "map",
                .any_kw => "any",
                .unknown_kw => "unknown",
                .pipe => "|",
                .comma => ",",
                .eq => "=",
                .colon => ":",
                .at => "@",
                .lb => "{",
                .rb => "}",
                .lsb => "[",
                .rsb => "]",
                .qmark => "?",
                .identifier => "(identifier)",
                .doc_comment_line => "(doc comment)",
                .bytes => "bytes",
                .int => "int",
                .float => "float",
                .bool => "bool",
                .eof => "EOF",

                .expr => "(expr)",
                .tag_name => "(tag name)",
            };
        }
    };

    pub const Loc = struct {
        start: u32,
        end: u32,

        pub fn src(self: Loc, code: []const u8) []const u8 {
            return code[self.start..self.end];
        }

        pub const Selection = struct {
            start: Position,
            end: Position,

            pub const Position = struct {
                line: u32,
                col: u32,
            };
        };

        pub fn getSelection(self: Loc, code: []const u8) Selection {
            //TODO: ziglyph
            var selection: Selection = .{
                .start = .{ .line = 1, .col = 1 },
                .end = undefined,
            };

            for (code[0..self.start]) |c| {
                if (c == '\n') {
                    selection.start.line += 1;
                    selection.start.col = 1;
                } else selection.start.col += 1;
            }

            selection.end = selection.start;
            for (code[self.start..self.end]) |c| {
                if (c == '\n') {
                    selection.end.line += 1;
                    selection.end.col = 1;
                } else selection.end.col += 1;
            }
            return selection;
        }
    };
};

const State = enum {
    start,
    identifier,
    doc_comment_start,
    doc_comment,
};

pub fn next(self: *Tokenizer, code: [:0]const u8) Token {
    var state: State = .start;
    var res: Token = .{
        .tag = .invalid,
        .loc = .{
            .start = self.idx,
            .end = undefined,
        },
    };

    while (true) : (self.idx += 1) {
        const c = code[self.idx];
        switch (state) {
            .start => switch (c) {
                0 => {
                    res.tag = .eof;
                    res.loc.start = @intCast(code.len - 1);
                    res.loc.end = @intCast(code.len);
                    break;
                },
                ' ', '\n', '\r', '\t' => res.loc.start += 1,
                '|' => {
                    self.idx += 1;
                    res.tag = .pipe;
                    res.loc.end = self.idx;
                    break;
                },
                ',' => {
                    self.idx += 1;
                    res.tag = .comma;
                    res.loc.end = self.idx;
                    break;
                },
                '=' => {
                    self.idx += 1;
                    res.tag = .eq;
                    res.loc.end = self.idx;
                    break;
                },
                ':' => {
                    self.idx += 1;
                    res.tag = .colon;
                    res.loc.end = self.idx;
                    break;
                },
                '@' => {
                    self.idx += 1;
                    res.tag = .at;
                    res.loc.end = self.idx;
                    break;
                },
                '[' => {
                    self.idx += 1;
                    res.tag = .lsb;
                    res.loc.end = self.idx;
                    break;
                },
                ']' => {
                    self.idx += 1;
                    res.tag = .rsb;
                    res.loc.end = self.idx;
                    break;
                },
                '{' => {
                    self.idx += 1;
                    res.tag = .lb;
                    res.loc.end = self.idx;
                    break;
                },
                '}' => {
                    self.idx += 1;
                    res.tag = .rb;
                    res.loc.end = self.idx;
                    break;
                },
                '?' => {
                    self.idx += 1;
                    res.tag = .qmark;
                    res.loc.end = self.idx;
                    break;
                },

                'a'...'z', 'A'...'Z', '_' => state = .identifier,
                '/' => state = .doc_comment_start,
                else => {
                    res.tag = .invalid;
                    res.loc.end = self.idx;
                    break;
                },
            },
            .identifier => switch (c) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue,
                else => {
                    res.loc.end = self.idx;
                    const src = res.loc.src(code);
                    if (std.mem.eql(u8, src, "bytes")) {
                        res.tag = .bytes;
                    } else if (std.mem.eql(u8, src, "bool")) {
                        res.tag = .bool;
                    } else if (std.mem.eql(u8, src, "int")) {
                        res.tag = .int;
                    } else if (std.mem.eql(u8, src, "float")) {
                        res.tag = .float;
                    } else if (std.mem.eql(u8, src, "struct")) {
                        res.tag = .struct_kw;
                    } else if (std.mem.eql(u8, src, "map")) {
                        res.tag = .map_kw;
                    } else if (std.mem.eql(u8, src, "any")) {
                        res.tag = .any_kw;
                    } else if (std.mem.eql(u8, src, "unknown")) {
                        res.tag = .unknown_kw;
                    } else if (std.mem.eql(u8, src, "root")) {
                        res.tag = .root_kw;
                    } else if (std.mem.eql(u8, src, "enum")) {
                        res.tag = .enum_kw;
                    } else {
                        res.tag = .identifier;
                    }
                    break;
                },
            },
            .doc_comment_start => switch (c) {
                '/' => {
                    if (!std.mem.startsWith(u8, code[self.idx..], "//")) {
                        res.tag = .invalid;
                        res.loc.end = self.idx;
                        break;
                    }
                    self.idx += 2;
                    state = .doc_comment;
                },
                else => {
                    res.tag = .invalid;
                    res.loc.end = self.idx;
                    break;
                },
            },
            .doc_comment => switch (c) {
                0, '\n' => {
                    res.tag = .doc_comment_line;
                    res.loc.end = self.idx;
                    break;
                },
                else => {},
            },
        }
    }

    return res;
}

test "basics" {
    const case =
        \\root = Frontmatter
        \\
        \\@date,
        \\
        \\struct Frontmatter {
        \\    title: bytes      
        \\}
    ;

    const expected: []const Token.Tag = &.{
        // zig fmt: off
        .root_kw, .eq, .identifier,
        
        .at, .identifier, .comma,
        
        .struct_kw, .identifier, .lb,
            .identifier, .colon, .bytes,
        .rb,
        // zig fmt: on
    };

    var t: Tokenizer = .{};

    for (expected, 0..) |e, idx| {
        errdefer std.debug.print("failed at index: {}\n", .{idx});
        const tok = t.next(case);
        errdefer std.debug.print("bad token: {any}\n", .{tok});
        try std.testing.expectEqual(e, tok.tag);
    }
        try std.testing.expectEqual(t.next(case).tag, .eof);
}

