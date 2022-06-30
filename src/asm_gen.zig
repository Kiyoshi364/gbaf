const std = @import("std");
const assert = std.debug.assert;
const Type = std.builtin.Type;
const Allocator = std.mem.Allocator;

const ArmSpec = &[_]Spec{};

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
.{ .fmt = "11011111 iiiiiiii", .name = "SoftwateInterrupt", },
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
        regm, regn, regd,
        offset, reloffset,
        cond, reglist, sbz,
        flag: struct { name: [1]u8 },
    };

    const TagEnum = @typeInfo(Tag).Union.tag_type.?;

    fn name(self: MSField) []const u8 {
        return switch (self.tag) {
            .fixed, .any, .immediate,
            .opcode1, .opcode,
            .regm, .regn, .regd,
            .offset, .reloffset,
            .cond, .reglist, .sbz, => @tagName(self.tag),
            .flag => |flag| &flag.name,
        };
    }

    pub fn format(
        self: MSField,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; _ = options;
        if ( self.sufix ) |sufix| {
            try std.fmt.format(writer, "{s}{}: u{}",
                .{ self.name(), sufix, self.size });
        } else {
            try std.fmt.format(writer, "{s}: u{}",
                .{ self.name(), self.size });
        }
        if ( @as(TagEnum, self.tag) == .fixed ) {
            const fixed = self.tag.fixed;
            try switch ( self.size ) {
                1 => writer.print(" = 0b{b:0>1}", .{ fixed }),
                2 => writer.print(" = 0b{b:0>2}", .{ fixed }),
                3 => writer.print(" = 0b{b:0>3}", .{ fixed }),
                4 => writer.print(" = 0b{b:0>4}", .{ fixed }),
                5 => writer.print(" = 0b{b:0>5}", .{ fixed }),
                6 => writer.print(" = 0b{b:0>6}", .{ fixed }),
                7 => writer.print(" = 0b{b:0>7}", .{ fixed }),
                8 => writer.print(" = 0b{b:0>8}", .{ fixed }),
                else => @panic("Unhandled size"),
            };
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
            'd' => .regd,
            'f' => .offset,
            'r' => .reloffset,
            'c' => .cond,
            'l' => .reglist,
            'z' => .sbz,
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
                .fixed, => |b| .{ .fixed = b << 1 | old.tag.fixed, },
                .any, .immediate,
                .opcode1, .opcode,
                .regm, .regn, .regd,
                .offset, .reloffset,
                .cond, .reglist,
                .sbz, => old.tag,
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

    pub fn format(
        self: MetaStruct,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; _ = options;
        try std.fmt.format(writer, "struct {{ ", .{});
        for (self.fields) |f| {
            try std.fmt.format(writer, "{}, ", .{ f });
        }
        try std.fmt.format(writer, "}}", .{});
    }

    fn fromSpec(spec: Spec, alloc: Allocator) !MetaStruct {
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
                    // @panic("asdfadf");
                }
            }
        }
        const fields = buffer[0..bsize];
        {
            // sanity check
            var total_size = @as(u8, 0);
            for (fields) |field| {
                total_size += field.size;
            }
            assert( total_size == 16 or total_size == 32 );
        }
        return MetaStruct{ .fields = fields, };
    }
};

fn fieldsFromSpec(specs: []const Spec, alloc: Allocator) ![]const MUField {
    const mu_fields = try alloc.alloc(MUField, specs.len);
    for (specs) |spec, i| {
        const mstruct = try MetaStruct.fromSpec(spec, alloc);
        mu_fields[i] = MUField.init(spec.name, mstruct);
    }
    return mu_fields;
}

const MUField = struct {
    name: []const u8,
    mstruct: MetaStruct,

    fn init(name: []const u8, mstruct: MetaStruct) MUField {
        return .{ .name = name, .mstruct = mstruct, };
    }

    pub fn format(
        self: MUField,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; _ = options;
        try std.fmt.format(writer, "{s}: {},",
            .{ self.name, self.mstruct });
    }
};

const MetaUnion = struct {
    name: []const u8,
    fields: []const MUField,

    fn init(name: []const u8, fields: []const MUField) MetaUnion {
        return .{ .name = name, .fields = fields, };
    }

    pub fn format(
        self: MetaUnion,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt; _ = options;
        try std.fmt.format(writer, "const {s} = union(enum) {{\n",
            .{ self.name });
        for (self.fields) |f| {
            try std.fmt.format(writer, "    {}\n", .{ f });
        }
        try std.fmt.format(writer, "}}\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();

    const thumb =
        MetaUnion.init("Thumb", try fieldsFromSpec(ThumbSpec, alloc));

    try std.io.getStdOut().writer().print("{}", .{ thumb });
}

fn todo() noreturn {
    @panic("This is not implemented!");
}

fn sliceEq(comptime T: type, a: []const T, b: []const T) bool {
    return if ( a.len != b.len ) false
        else for (a) |_, i| {
            if ( a[i] != b[i] ) break false;
        } else true;
}
