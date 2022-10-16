const std = @import("std");

const gen = @import("gen.zig");
const MetaUnion = gen.MetaUnion;
const print_code = gen.print_code;
const indent = gen.indent;
const indent_print = gen.indent_print;

pub const funcs = [_][]const u8 {
    "from_int", "to_int", "debug_print",
};

pub fn from_int(depth: usize, writer: anytype, mu: MetaUnion) !void {
    try indent_print(depth, writer,
        "pub fn from_int(input: u{d}) {s} {{\n",
        .{ mu.bitsize, mu.name });
    try indent_print(depth+1, writer,
        "var best_match = @as(?{s}, null);\n",
        .{ mu.name });
    try indent_print(depth+1, writer,
        "var best_score = @as(u8, 0);\n", .{});
    try indent_print(depth+1, writer,
        "var score = @as(u8, undefined);\n", .{});
    for (mu.fields) |muf| {
            try indent_print(depth+1, writer,
                "{{ // {s}\n", .{ muf.name });
        try indent_print(depth+2, writer,
            "var iter = UintIterator({d}){{ .value = input, }};\n",
            .{ mu.bitsize });
        try indent_print(depth+2, writer,
            "score = 0;\n", .{});
        try indent_print(depth+2, writer,
            "var valid = true;\n", .{});
        try indent_print(depth+2, writer,
            "var value = @as({s}, undefined);\n",
            .{ muf.name });
        for (muf.mstruct.fields) |msf| {
            if ( msf.tag == .fixed ) {
                try indent_print(depth+2, writer,
                    "score += {d};\n", .{ msf.size });
                try indent_print(depth+2, writer,
                    "valid = iter.pop({d}) == ",
                    .{ msf.size });
                try msf.toFixedString(writer);
                try std.fmt.format(writer, " and valid;\n", .{});
            } else {
                try indent_print(depth+2, writer,
                    "value.", .{});
                try msf.print_name(writer);
                try std.fmt.format(writer, " = iter.pop({d});\n",
                    .{ msf.size });
            }
        }
        try print_code(depth+2, writer,
            \\assert( iter.isDone() );
            \\if ( valid and score >= best_score ) {
            \\    if( score == best_score ) {
            \\        std.debug.print("best({d}): {any}\nnew({d}): {any}\n",
            \\            .{ best_score, best_match, score, value });
            \\    }
            \\    best_score = score;
            \\
            );
        try indent_print(depth+3, writer,
            "best_match = {s}{{ .{s} = value }};\n",
            .{ mu.name, muf.name });
        try print_code(depth+1, writer,
            \\    }
            \\}
            \\
            );
    }
    try print_code(depth, writer,
        \\    return best_match.?;
        \\}
        \\
        );
}

pub fn to_int(depth: usize, writer: anytype, mu: MetaUnion) !void {
    try indent_print(depth, writer,
        "pub fn to_int(self: {s}) u{d} {{\n",
        .{ mu.name, mu.bitsize });
    try indent_print(depth+1, writer,
        "var builder = UintBuilder({d}){{}};\n", .{ mu.bitsize });
    try print_code(depth+1, writer,
        "return switch (self) {\n");
    for (mu.fields) |muf| {
        try indent_print(depth+2, writer, ".{s} => |val|\n",
            .{ muf.name });
        try indent_print(depth+3, writer, "builder\n", .{});
        for (muf.mstruct.fields) |msf| {
            if ( msf.tag == .fixed ) {
                try indent_print(depth+4, writer,
                    ".append({d}, ", .{ msf.size });
                try msf.toFixedString(writer);
            } else {
                try indent_print(depth+4, writer,
                    ".append({d}, val.",
                    .{ msf.size });
                try msf.print_name(writer);
            }
            try std.fmt.format(writer, ")\n", .{});
        }
        try print_code(depth+4, writer,
            \\.done(),
            \\
            );
    }
    try print_code(depth, writer,
        \\    };
        \\}
        \\
        );
}

pub fn debug_print(depth: usize, writer: anytype, mu: MetaUnion) !void {
    try indent_print(depth, writer,
        "pub fn debug_print(self: {s}, writer: anytype) !void {{\n",
        .{ mu.name });
    try print_code(depth+1, writer,
        "switch (self) {\n");
    for (mu.fields) |muf| {
        try indent_print(depth+2, writer, ".{s} => |val| {{\n",
            .{ muf.name });
        try indent_print(depth+3, writer,
            \\try std.fmt.format(writer, "{s}", .{{}});
            \\
            , .{ muf.name });
        for (muf.mstruct.fields) |msf| {
            if ( msf.tag == .fixed ) {
                // noop
            } else {
                try indent_print(depth+3, writer,
                    \\try std.fmt.format(writer, " 
                    , .{});
                try msf.print_name(writer);
                try std.fmt.format(writer,
                    \\=0b{{b:0>{d}}}", .{{ val.
                    , .{ msf.size });
                try msf.print_name(writer);
                try std.fmt.format(writer, " }});\n", .{});
            }
        }
        try print_code(depth+2, writer,
            \\},
            \\
            );
    }
    try print_code(depth, writer,
        \\    }
        \\    try std.fmt.format(writer, "\n", .{});
        \\}
        \\
        );
}
