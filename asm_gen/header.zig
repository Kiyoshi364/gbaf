const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

fn OfftableEntry(comptime Bsize: type) type {
    assert( Bsize == u16 or Bsize == u32 );
    const Urot = if ( Bsize == u16 ) u4 else u8;
    return struct {
        name: []const u8,
        offset: u8,
        size: Urot,
        isFixed: Tag,
        const Enum = @typeInfo(Tag).Union.tag_type.?;
        const Tag = union(enum){
            nil,
            fixed: Bsize,
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
        for ( @field(UField, "offtable") ) |entry| {
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
        for ( @field(UField, "offtable") ) |entry| {
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

fn UintBuilder(comptime target_size: comptime_int, comptime used: ?comptime_int)
        if (used) |_| type else UintBuilder(target_size, 0) {
    if ( used ) |used_bits| {
        assert( 0 < target_size );
        assert( 0 <= used_bits and used_bits <= target_size );
        const Target = Uint(target_size);
        return struct {
            value: Target,

            fn append(self: @This(), comptime size: comptime_int, bits: Uint(size)) UintBuilder(target_size, used_bits + size) {
                if ( used_bits + size > target_size ) {
                    @compileError("More bits than can fit");
                }
                const shift = target_size - used_bits - size;
                const value = self.value | @as(Target, bits) << shift;
                return UintBuilder(target_size, used_bits + size){
                    .value = value,
                };
            }

            fn finish(self: @This(), comptime size: comptime_int, bits: Uint(size)) Target {
                if ( used_bits + size != target_size ) {
                    @compileError("Not enough bits to finish");
                }
                return self.append(size, bits).value;
            }
        };
    } else {
        return .{ .value = 0, };
    }
}

test "UintBuilder" {
    const builder1 = UintBuilder(8, null);
    const result1 =
        builder1.append(1, 0b1).append(3, 0b000).finish(4, 0b1010);
    try testing.expectEqual(@as(u8, 0b1000_1010), result1);
    const builder2 = UintBuilder(16, null);
    const result2 =
        builder2.append(3, 0b001).append(3, 0b101).append(6, 0b001100)
        .finish(4, 0b1010);
    try testing.expectEqual(@as(u16, 0b001_101_001100_1010), result2);
}
