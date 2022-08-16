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
