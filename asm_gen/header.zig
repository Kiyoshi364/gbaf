const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

fn hasPrefix(name: []const u8, prefix: []const u8) bool {
    return for (prefix) |c, i| {
        if ( name[i] != c ) break false;
    } else true;
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

fn UintIterator(comptime size: comptime_int) type {
    assert( size > 0 );
    const Ufits = switch (size) {
        8 => u4,
        16 => u5,
        32 => u6,
        else => @compileError("unhandled size"),
    };
    const Urot = switch (size) {
        8 => u3,
        16 => u4,
        32 => u5,
        else => @compileError("unhandled size"),
    };
    return struct {
        value: Uint(size),
        used_bits: Ufits = 0,

        fn pop(self: *@This(), comptime count: Ufits) Uint(count) {
            assert( count > 0 );
            assert( size >= self.used_bits + count );
            const shift = @intCast(Urot,
                size - self.used_bits - count);
            self.used_bits += count;
            return @truncate(Uint(count), self.value >> shift);
        }

        fn isDone(self: @This()) bool {
            return self.used_bits == size;
        }
    };
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
