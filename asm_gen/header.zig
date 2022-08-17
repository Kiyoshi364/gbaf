const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

fn OfftableEntry(comptime Bsize: type) type {
    assert( Bsize == u16 or Bsize == u32 );
    return struct {
        name: []const u8,
        offset: comptime_int,
        size: comptime_int,
        isFixed: Tag,
        const Enum = @typeInfo(Tag).Union.tag_type.?;
        const Tag = union(enum){
            nil,
            fixed: comptime_int,
        };
    };
}

test "OfftableEntry compiles" {
    const OE16 = OfftableEntry(u16);
    testing.refAllDecls(OE16);
    const OE32 = OfftableEntry(u32);
    testing.refAllDecls(OE32);
}

fn hasPrefix(name: []const u8, prefix: []const u8) bool {
    return for (prefix) |c, i| {
        if ( name[i] != c ) break false;
    } else true;
}

test "Thumb's OfftableEntry fixed has value, non-fixed don't" {
    const thumbFields = @typeInfo(Thumb).Union.fields;
    inline for (thumbFields) |ufield| {
        const UField = ufield.field_type;
        assert( @hasDecl(UField, "offtable") );
        inline for ( @field(UField, "offtable") ) |entry| {
            const Enum = @TypeOf(entry).Enum;
            if ( hasPrefix(entry.name, "fixed") ) {
                try testing.expectEqual(
                    Enum.fixed, @as(Enum, entry.isFixed));
            } else {
                try testing.expectEqual(
                    Enum.nil, @as(Enum, entry.isFixed));
            }
        }
    }
}

test "Arm's OfftableEntry fixed has value, non-fixed don't" {
    const armFields = @typeInfo(Arm).Union.fields;
    inline for (armFields) |ufield| {
        const UField = ufield.field_type;
        assert( @hasDecl(UField, "offtable") );
        inline for ( @field(UField, "offtable") ) |entry| {
            const Enum = @TypeOf(entry).Enum;
            if ( hasPrefix(entry.name, "fixed") ) {
                try testing.expectEqual(
                    Enum.fixed, @as(Enum, entry.isFixed));
            } else {
                try testing.expectEqual(
                    Enum.nil, @as(Enum, entry.isFixed));
            }
        }
    }
}

fn Uint(comptime bits: comptime_int) type {
    return @Type(.{
        .Int = .{ .signedness = .unsigned, .bits = bits, }});
}

fn UintBuilder(comptime target_size: comptime_int) type {
    assert( 0 < target_size );
    const Target = Uint(target_size);
    const Urot = switch (target_size) {
        8 => u3,
        16 => u4,
        32 => u5,
        else => @compileError("unhandled size"),
    };
    return struct {
        value: Target = 0,
        used_bits: Urot = 0,
        is_done: bool = false,

        fn append(self: @This(), comptime size: Urot, bits: Uint(size)) UintBuilder(target_size) {
            const used = @as(Target, self.used_bits) + size;
            assert( size > 0 );
            assert( used <= target_size );
            const shift = @as(Urot,
                    target_size - 1 - size + 1 - self.used_bits);
            const value = self.value | @as(Target, bits) << shift;
            return UintBuilder(target_size){
                .value = value,
                .used_bits = self.used_bits +% size,
                .is_done = used == target_size,
            };
        }

        fn finish(self: @This(), comptime size: comptime_int, bits: Uint(size)) Target {
            const used = @as(Target, self.used_bits) + size;
            assert( used == target_size );
            return self.append(size, bits).value;
        }

        fn done(self: @This()) Target {
            assert ( self.is_done );
            return self.value;
        }
    };
}

test "UintBuilder" {
    const builder1 = UintBuilder(8){};
    const result1 =
        builder1.append(1, 0b1).append(3, 0b000).append(4, 0b1010);
    try testing.expectEqual(@as(u8, 0b1000_1010), result1.done());
    const builder2 = UintBuilder(16){};
    const result2 =
        builder2.append(3, 0b001).append(3, 0b101).append(6, 0b001100)
        .finish(4, 0b1010);
    try testing.expectEqual(@as(u16, 0b001_101_001100_1010), result2);
}

fn strEq(str1: []const u8, str2: []const u8) bool {
    return if ( str1.len == str2.len )
        for (str1) |c, i| {
            if ( c != str2[i] ) break false;
        } else true
    else false;
}

test "strEq" {
    try testing.expect(strEq("asdf", "asdf"));
    try testing.expect(!strEq("asd", "asdf"));
    try testing.expect(!strEq("asdh", "asdf"));
}
