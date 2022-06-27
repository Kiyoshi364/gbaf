const std = @import("std");
const assert = std.debug.assert;
const Type = std.builtin.Type;

const Arm = MakeInst(ArmSpec);

const ArmSpec = &[_]Spec{};

const Thumb = MakeInst(ThumbSpec);

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

fn MakeInst(comptime specs: []const Spec) type {
    var fields: [specs.len]Type.UnionField = undefined;
    for (specs) |spec, i| {
        const field_type = FieldTypeFromFmt(spec.fmt);
        fields[i] = .{
            .name = spec.name,
            .field_type = field_type,
            .alignment = @alignOf(field_type),
        };
    }
    return @Type(Type{ .Union = .{
        .layout = .Auto,
        .tag_type = null,
        .fields = &fields,
        .decls = &.{},
    }});
}

const MiniField = struct {
    const Self = @This();

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

    fn name(comptime self: Self) []const u8 {
        return switch (self.tag) {
            .fixed, .any, .immediate,
            .opcode1, .opcode,
            .regm, .regn, .regd,
            .offset, .reloffset,
            .cond, .reglist, .sbz, => @tagName(self.tag),
            .flag => |flag| &flag.name,
        } ++ if ( self.sufix ) |c| [_]u8{c} else [_]u8{};
    }

    const TagEnum = @typeInfo(Tag).Union.tag_type.?;

    fn init(comptime char: u8) MSelf {
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
            else => @compileError("Unhandled char: \"" ++ [_]u8{char}
                    ++ "\""),
        };
        return .{ .val = .{ .tag = tag, } };
    }

    const MSelf = union(enum) {
        val: Self, empty,

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

        fn try_unwrap(mself: MSelf) ?Self {
            return switch (mself) {
                .val =>  |val| val,
                .empty => null,
            };
        }

        fn unwrap(comptime mself: MSelf) Self {
            return if ( mself.try_unwrap() ) |val| val
                else @compileError("Unwrapping an empty MSelf");
        }
    };
};

fn FieldTypeFromFmt(fmt: []const u8) type {
    var buffer: [fmt.len]MiniField = undefined;
    var bsize = 0;
    {
        // Read and gather MiniFields
        var acc: MiniField.MSelf = .empty;
        for (fmt) |c| {
            const new = MiniField.init(c);
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
        var i = 1;
        while ( i < bsize ) : ( i += 1 ) {
            const mf = &buffer[i];
            var j = i - 1;
            while ( j >= 0 ) : ( j -= 1 ) {
                const other = &buffer[j];
                if ( @as(MiniField.TagEnum, mf.*.tag)
                        == @as(MiniField.TagEnum, other.*.tag) ) {
                    const isFlag =
                        @as(MiniField.TagEnum, mf.*.tag) == .flag;
                    const sameFlag = isFlag
                        and sliceEq(u8, &mf.*.tag.flag.name,
                            &other.*.tag.flag.name);
                    if ( !isFlag or sameFlag ) {
                        other.*.sufix = other.*.sufix orelse '1';
                        mf.*.sufix = other.*.sufix.? + 1;
                    }
                    break;
                }
            }
        }
    }
    var fields: [bsize]Type.StructField = undefined;
    {
        // Build fields
        var i = 0;
        var total_size = 0;
        while ( i < bsize ) : ( i += 1 ) {
            const mf = buffer[i];
            const field_type = @Type(.{ .Int = .{
                .signedness = .unsigned,
                .bits = mf.size,
            }});
            total_size += mf.size;
            fields[i] = .{
                .name = mf.name(),
                .field_type = field_type,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(field_type),
            };
        }
    }
    return @Type(Type{ .Struct = .{
        .layout = .Auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    }});
}

test "ThumbSpec compiles" {
    @setEvalBranchQuota(2583);
    _ = MakeInst(ThumbSpec);
}

test "ArmSpec compiles" {
    @setEvalBranchQuota(1000);
    _ = MakeInst(ArmSpec);
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
