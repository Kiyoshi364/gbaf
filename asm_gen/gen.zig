const std = @import("std");
const assert = std.debug.assert;
const Type = std.builtin.Type;
const Allocator = std.mem.Allocator;

const header = @embedFile("header.zig");
const decls = @embedFile("decls.zig");
const tests = @embedFile("tests.zig");
const arm_code = @embedFile("arm.zig");
const thumb_code = @embedFile("thumb.zig");

const ver = std.SemanticVersion.parse("0.10.0-dev.2489") catch unreachable;
const curr_ver = @import("builtin").zig_version;
const is_new_ver = curr_ver.order(ver) == .gt;

const ArmSpec = &[_]Spec{
.{ .fmt = "cccc000o oooSnnnn ddddaaaa ahh0mmmm", .name = "DataProcessingImmediateShift", },
.{ .fmt = "cccc0001 0xx0xxxx xxxxxxxx xxx0xxxx", .name = "MiscellaneousInstructions", },
.{ .fmt = "cccc000o oooSnnnn ddddssss 0hhhmmmm", .name = "DataProcessingRegisterShift", },
.{ .fmt = "cccc0001 0xx0xxxx xxxxxxxx 0xx1xxxx", .name = "MiscellaneousInstructions2", },
.{ .fmt = "cccc000x xxxxxxxx xxxxxxxx 1xx1xxxx", .name = "MultipliesExtraLoadStores", },
.{ .fmt = "cccc001o oooSnnnn ddddtttt iiiiiiii", .name = "DataProcessingImmediate", },
.{ .fmt = "cccc0011 0x00xxxx xxxxxxxx xxxxxxxx", .name = "UndefinedInstruction", },
.{ .fmt = "cccc0011 0R10kkkk SBOPtttt iiiiiiii", .name = "MoveImmediateToStatusRegister", },
.{ .fmt = "cccc010P UBWLnnnn ddddiiii iiiiiiii", .name = "LoadStoreImmediateOffset", },
.{ .fmt = "cccc011P UBWLnnnn ddddaaaa ahh0mmmm", .name = "LoadStoreRegisterOffset", },
.{ .fmt = "cccc011x xxxxxxxx xxxxxxxx xxx1xxxx", .name = "MediaInstructions", },
.{ .fmt = "cccc0111 1111xxxx xxxxxxxx 1111xxxx", .name = "ArchtecturallyUndefined", },
.{ .fmt = "cccc100P USWLnnnn llllllll llllllll", .name = "LoadStoreMultiple", },
.{ .fmt = "cccc101L ffffffff ffffffff ffffffff", .name = "BranchAndBranchWithLink", },
.{ .fmt = "cccc110P UNWLnnnn ddddpppp ffffffff", .name = "CoprocessorLoadStoreAndDoubleRegisterTransfers", },
.{ .fmt = "cccc1110 oooonnnn ddddpppp ....0mmm", .name = "CoprocessorDataProcessing", },
.{ .fmt = "cccc1110 oooLnnnn ddddpppp ....1mmm", .name = "CoprocessorRegisterTransfers", },
.{ .fmt = "cccc1111 iiiiiiii iiiiiiii iiiiiiii", .name = "SoftwareInterrupt", },
.{ .fmt = "1111xxxx xxxxxxxx xxxxxxxx xxxxxxxx", .name = "UnconditionalInstructions", },
};

const ThumbSpec = &[_]Spec{
.{ .fmt = "000..iii iimmmddd", .name = "ShiftByImmediate", },
.{ .fmt = "000110om mmnnnddd", .name = "AddSubRegister", },
.{ .fmt = "000111oi iinnnddd", .name = "AddSubImmediate", },
.{ .fmt = "001oonnn iiiiiiii", .name = "AddSubCmpMovImmediate", },
.{ .fmt = "010000oo oommmnnn", .name = "DataProcessingRegister", },
.{ .fmt = "010001.. HHmmmnnn", .name = "SpecialDataProcessing", },
.{ .fmt = "01000111 LHmmmzzz", .name = "BranchExchange", },
.{ .fmt = "01001ddd rrrrrrrr", .name = "LoadFromLiteralPool", },
.{ .fmt = "0101ooom mmnnnddd", .name = "LoadStoreRegisterOffset", },
.{ .fmt = "011BLfff ffnnnddd", .name = "LoadStoreWordByteImmediateOffset", },
.{ .fmt = "1000Lfff ffnnnddd", .name = "LoadStoreHalfwordImmediateOffset", },
.{ .fmt = "1001Lddd rrrrrrrr", .name = "LoadStoreFromToStack", },
.{ .fmt = "1010Sddd iiiiiiii", .name = "AddToSpOrPc", },
.{ .fmt = "1011xxxx xxxxxxxx", .name = "Miscellaneous", },
.{ .fmt = "1100Lnnn llllllll", .name = "LoadStoreMultiple", },
.{ .fmt = "1101cccc ffffffff", .name = "ConditionalBranch", },
.{ .fmt = "11011110 xxxxxxxx", .name = "UndefinedInstruction", },
.{ .fmt = "11011111 iiiiiiii", .name = "SoftwareInterrupt", },
.{ .fmt = "11100fff ffffffff", .name = "UnconditionalBranch", },
.{ .fmt = "11101fff fffffff0", .name = "BlxSuffix", },
.{ .fmt = "11101fff fffffff1", .name = "UndefinedInstruction2", },
.{ .fmt = "11110fff ffffffff", .name = "BlBlxPrefix", },
.{ .fmt = "11111fff ffffffff", .name = "BlSuffix", },
};

const Spec = struct { fmt: []const u8, name: []const u8, };

const MSField = struct {
    size: u8 = 1,
    sufix: ?u8 = null,
    tag: Tag,

    const Tag = union(enum) {
        fixed: u8, any, immediate,
        opcode1, opcode,
        regm, regn, regd, regs,
        offset, reloffset,
        cond, reglist, sbz,
        shiftamount, shift,
        rotate, mask, cp_num,
        flag: struct { name: [1]u8 },
    };

    const TagEnum = @typeInfo(Tag).Union.tag_type.?;

    fn name(self: *const MSField) []const u8 {
        return switch (self.tag) {
            .fixed, .any, .immediate,
            .opcode1, .opcode,
            .regm, .regn, .regd, .regs,
            .offset, .reloffset,
            .cond, .reglist, .sbz,
            .shiftamount, .shift,
            .rotate, .mask, .cp_num => @tagName(self.tag),
            .flag => |*flag| &flag.name,
        };
    }

    fn print_default_value(self: MSField, writer: anytype) !void {
        if ( @as(MSField.TagEnum, self.tag) == .fixed ) {
            const fixed = self.tag.fixed;
            try std.fmt.format(writer, ".{{ .fixed = ", .{});
            try switch ( self.size ) {
                1 => writer.print("0b{b:0>1}", .{ fixed }),
                2 => writer.print("0b{b:0>2}", .{ fixed }),
                3 => writer.print("0b{b:0>3}", .{ fixed }),
                4 => writer.print("0b{b:0>4}", .{ fixed }),
                5 => writer.print("0b{b:0>5}", .{ fixed }),
                6 => writer.print("0b{b:0>6}", .{ fixed }),
                7 => writer.print("0b{b:0>7}", .{ fixed }),
                8 => writer.print("0b{b:0>8}", .{ fixed }),
                else => @panic("Unhandled size"),
            };
            try std.fmt.format(writer, " }}", .{});
        } else {
            try std.fmt.format(writer,
                 if (is_new_ver) ".{{ .nil = {{}} }}"
                 else ".{{ .nil = .{{}} }}", .{});
        }
    }

    pub fn print(
        self: MSField,
        depth: usize,
        writer: anytype,
    ) !void {
        _ = depth;
        assert( @as(TagEnum, self.tag) != .fixed );
        if ( self.sufix ) |sufix| {
            try std.fmt.format(writer, "{s}{}: u{}",
                .{ self.name(), sufix, self.size });
        } else {
            try std.fmt.format(writer, "{s}: u{}",
                .{ self.name(), self.size });
        }
    }

    fn init(char: u8) MSelf {
        const tag: Tag = switch (char) {
            '0', '1' => .{ .fixed = char - '0', },
            'x' => .any,
            'i' => .immediate,
            '.' => .opcode1,
            'o' => .opcode,
            'm' => .regm,
            'n' => .regn,
            's' => .regs,
            'd' => .regd,
            'f' => .offset,
            'r' => .reloffset,
            'c' => .cond,
            'l' => .reglist,
            'z' => .sbz,
            'a' => .shiftamount,
            'h' => .shift,
            't' => .rotate,
            'k' => .mask,
            'p' => .cp_num,
            'A' ... 'Z' => .{ .flag = .{ .name = [1]u8{ char }, } },
            ' ' => return .empty,
            else => @panic("Unhandled char"),
        };
        return MSelf{ .val = .{ .tag = tag, } };
    }

    const MSelf = union(enum) {
        val: MSField, empty,

        fn concat(m_old: MSelf, m_new: MSelf) ?MSelf {
            if ( m_old == .empty ) return m_new;
            if ( m_new == .empty ) return m_old;
            const old = m_old.val;
            const new = m_new.val;
            if ( @as(TagEnum, old.tag) != @as(TagEnum, new.tag) ) {
                return null;
            }
            if ( @as(TagEnum, old.tag) == .flag ) {
                return null;
            }

            assert( new.size == 1 );
            const tag: Tag = switch (old.tag) {
                .fixed, => |b| .{ .fixed = b << 1 | new.tag.fixed, },
                .any, .immediate,
                .opcode1, .opcode,
                .regm, .regn, .regd, .regs,
                .offset, .reloffset,
                .cond, .reglist, .sbz,
                .shiftamount, .shift,
                .rotate, .mask, .cp_num, => old.tag,
                .flag, => unreachable,
            };

            return MSelf{ .val = .{
                .size = old.size + new.size,
                .tag = tag,
            }};
        }

        fn try_unwrap(mself: MSelf) ?MSField {
            return switch (mself) {
                .val =>  |val| val,
                .empty => null,
            };
        }

        fn unwrap(mself: MSelf) MSField {
            return if ( mself.try_unwrap() ) |val| val
                else @panic("Unwrapping an empty MSelf");
        }
    };
};

const MetaStruct = struct {
    fields: []const MSField,
    offsets: []const u8,

    pub fn print(
        self: MetaStruct,
        depth: usize,
        writer: anytype,
    ) !void {
        try std.fmt.format(writer, "struct {{\n", .{});
        try indent_print(depth+1, writer,
            "const offtable = [{d}]OfftableEntry(Bits){{\n",
            .{ self.fields.len });
        for (self.fields) |f, i| {
            var buffer = [1]u8{ 0 } ** 2;
            const sufix = blk: {
                if ( f.sufix ) |s| {
                    const d0 = s / 10;
                    const d1 = s % 10;
                    assert( d0 < 10 );
                    if ( d0 == 0 ) {
                        assert( 0 < d1 and d1 < 10 );
                        buffer[0] = d1 + '0';
                        break :blk buffer[0..1];
                    } else {
                        buffer[0] = d0 + '0';
                        buffer[1] = d1 + '0';
                        break :blk buffer[0..2];
                    }
                } else {
                    break :blk buffer[0..0];
                }
            };
            try indent_print(depth+2, writer,
                \\.{{ .name = "{s}{s}", .offset = {d},
                , .{ f.name(), sufix, self.offsets[i], });
            try std.fmt.format(writer, " .size = {d}, .isFixed = ",
                .{ f.size });
            try f.print_default_value(writer);
            try std.fmt.format(writer, ", }},\n", .{});
        }
        try indent_print(depth+1, writer, "}};\n", .{});
        for (self.fields) |f| {
            if ( @as(MSField.TagEnum, f.tag) == .fixed ) continue;
            try indent(depth+1, writer);
            try f.print(depth+1, writer);
            try std.fmt.format(writer, ",\n", .{});
        }
        try indent_print(depth, writer, "}}", .{});
    }

    const FromSpec = struct { mstruct: MetaStruct, bsize: u8 };
    fn fromSpec(spec: Spec, alloc: Allocator) !FromSpec {
        const fmt = spec.fmt;
        var buffer = try alloc.alloc(MSField, fmt.len);
        var bsize = @as(usize, 0);
        {
            // Read and gather MSFields
            var acc: MSField.MSelf = .empty;
            for (fmt) |c| {
                const new = MSField.init(c);
                if ( acc.concat(new) ) |mf| {
                    acc = mf;
                } else {
                    buffer[bsize] = acc.unwrap();
                    bsize += 1;
                    acc = new;
                }
            } else {
                buffer[bsize] = acc.unwrap();
                bsize += 1;
            }
        }
        {
            // Use sufix to make names unique
            for ( buffer[0..bsize] ) |*mf, i| {
                var j = i -% 1;
                while ( j < @as(usize, 0) -% 1 ) : ( j -%= 1 ) {
                    const other = &buffer[j];
                    if ( @as(MSField.TagEnum, mf.*.tag)
                            == @as(MSField.TagEnum, other.*.tag)
                    ) {
                        const isFlag =
                            @as(MSField.TagEnum, mf.*.tag) == .flag;
                        const sameFlag = isFlag
                            and sliceEq(u8, &mf.*.tag.flag.name,
                                &other.*.tag.flag.name);
                        if ( !isFlag or sameFlag ) {
                            other.*.sufix = other.*.sufix orelse 1;
                            mf.*.sufix = other.*.sufix.? + 1;
                        }
                        break;
                    }
                }
            }
        }
        const fields = buffer[0..bsize];
        const offsets = try alloc.alloc(u8, bsize);
        var total_size = @as(u8, 0);
        {
            for (fields) |field, i| {
                offsets[i] = total_size;
                total_size += field.size;
            }
            assert( total_size == 16 or total_size == 32 );
        }
        return FromSpec{
            .mstruct = MetaStruct{
                .fields = fields,
                .offsets = offsets,
            },
            .bsize = total_size,
        };
    }
};

const FieldsFromSpec = struct {
    mu_fields: []const MUField,
    bsize: u8,
};
fn fieldsFromSpec(specs: []const Spec, alloc: Allocator) !FieldsFromSpec {
    const mu_fields = try alloc.alloc(MUField, specs.len);
    var bsize = @as(?u8, null);
    for (specs) |spec, i| {
        const fromSpec = try MetaStruct.fromSpec(spec, alloc);
        if ( bsize ) |bs| {
            assert( bs == fromSpec.bsize );
        } else {
            bsize = fromSpec.bsize;
        }
        mu_fields[i] = MUField.init(spec.name, fromSpec.mstruct);
    }
    return FieldsFromSpec{
        .mu_fields = mu_fields,
        .bsize = bsize.?,
    };
}

const MUField = struct {
    name: []const u8,
    mstruct: MetaStruct,

    fn init(name: []const u8, mstruct: MetaStruct) MUField {
        return .{ .name = name, .mstruct = mstruct, };
    }

    pub fn print(
        self: MUField,
        depth: usize,
        writer: anytype,
    ) !void {
        try indent_print(depth, writer, "{s}: ", .{ self.name });
        try self.mstruct.print(depth, writer);
        try std.fmt.format(writer, ",\n", .{});
    }
};

const MetaUnion = struct {
    name: []const u8,
    fields: []const MUField,
    bitsize: u8,
    decls: []const u8,
    code: []const u8,

    fn init(name: []const u8, spec: []const Spec, dcl: []const u8, code: []const u8, alloc: std.mem.Allocator) !MetaUnion {
        const ffs = try fieldsFromSpec(spec, alloc);
        return MetaUnion{
            .name = name,
            .fields = ffs.mu_fields,
            .bitsize = ffs.bsize,
            .decls = dcl,
            .code = code,
        };
    }

    pub fn format(
        self: MetaUnion,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; _ = options;
        try std.fmt.format(writer, "pub const {s} = union(enum) {{\n",
            .{ self.name });
        for (self.fields) |f| {
            try f.print(1, writer);
        }
        try std.fmt.format(writer, "\n", .{});
        try print_constants(1, writer, self);
        try std.fmt.format(writer, "\n", .{});
        try print_code(1, writer, self.decls);
        try std.fmt.format(writer, "\n", .{});
        try print_code(1, writer, self.code);
        try std.fmt.format(writer, "}};\n", .{});
    }
};

fn print_constants(depth: usize, writer: anytype, mu: MetaUnion) !void {
    assert( mu.bitsize == 16 or mu.bitsize == 32 );
    try indent_print(depth, writer, "const Self = @This();\n", .{});
    try indent_print(depth, writer, "const selfInfo ="
        ++ " @typeInfo(Self).Union;\n", .{});
    try indent_print(depth, writer, "const bitsize = {d};\n",
        .{ mu.bitsize });
    try indent_print(depth, writer, "const Bits = u{d};\n",
        .{ mu.bitsize });
    const rot = if ( mu.bitsize == 16 ) @as(u8, 4) else @as(u8, 8);
    try indent_print(depth, writer, "const BitRot = u{d};\n", .{ rot });
}

fn print_code(depth: usize, writer: anytype, dcls: []const u8) !void {
    var i: usize = 0;
    while ( i < dcls.len ) {
        const last = i;
        while ( i < dcls.len and dcls[i] != '\n') : ( i += 1 ) {}
        if ( dcls[i] == '\n' ) {
            i += 1;
        }
        if ( i - last > 1 ) try indent(depth, writer);
        try std.fmt.format(writer, "{s}", .{ dcls[last..i] });
    }
}

fn indent(depth: usize, writer: anytype) !void {
    var i = @as(usize, 0);
    while ( i < depth ) : ( i += 1 ) {
        try writer.print("    ", .{});
    }
}

fn indent_print(
        depth: usize, writer: anytype,
        comptime fmt: []const u8, args: anytype) !void {
    try indent(depth, writer);
    try std.fmt.format(writer, fmt, args);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const thumb =
        try MetaUnion.init("Thumb", ThumbSpec, decls,
            thumb_code, alloc);

    const arm =
        try MetaUnion.init("Arm", ArmSpec, decls,
            arm_code, alloc);

    const asmfile = try std.fs.cwd().createFile( "src/asm.zig", .{} );
    defer asmfile.close();
    var out = asmfile.writer();

    try out.print("{s}\n", .{ header });
    try out.print("{}\n", .{ thumb });
    try out.print("{}\n", .{ arm });
    try out.print("{s}\n", .{ tests });
}

fn todo() noreturn {
    @panic("This is not implemented!");
}

fn sliceEq(comptime T: type, a: []const T, b: []const T) bool {
    return if ( a.len != b.len ) false
        else if ( a.ptr == b.ptr ) true
        else for (a) |_, i| {
            if ( a[i] != b[i] ) break false;
        } else true;
}
