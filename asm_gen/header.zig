const std = @import("std");
const assert = std.debug.assert;

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
