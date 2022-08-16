const testing = std.testing;

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

test "Thumb dummy instruction" {
    const inst = Thumb{ .AddSubRegister = .{
        .opcode = 1, .regm = 2, .regn = 4, .regd = 7,
    }};
    testing.refAllDecls(Thumb);
    _ = inst;
}

test "Arm dummy instruction" {
    const inst = Arm{ .DataProcessingImmediateShift = .{
        .cond = 0, .opcode = 1, .S = 0, .regn = 2, .regd = 3,
        .shiftamount = 4, .shift = 2, .regm = 7,
    }};
    testing.refAllDecls(Arm);
    _ = inst;
}

test "Thumb instruction from int" {
    const inst = Thumb.read_int(0b000_01_00100_111_000);
    try testing.expectEqual(Thumb{ .ShiftByImmediate = .{
            .opcode1 = 0b01,
            .immediate = 0b00100,
            .regm = 0b111,
            .regd = 0b000,
        }}, inst);
}

test "Arm instruction from int 1" {
    const inst = Arm.read_int(0b1010_1110_101_0_1111_0000_0101_1110_1_010);
    const expected = Arm{ .CoprocessorRegisterTransfers = .{
        .cond = 0b1010, .opcode = 0b101,
        .L = 0b0, .regn = 0b1111, .regd = 0b0000,
        .cp_num = 0b0101, .opcode1 = 0b1110, .regm = 0b010,
    }};
    try testing.expectEqual(expected, inst);
}

test "Arm instruction from int 2" {
    const inst = Arm.read_int(0b1010_100_10101_1000_10110111_01001000);
    const expected =
        Arm{ .LoadStoreMultiple = .{
            .cond = 0b1010,
            .P = 0b1, .U = 0b0, .S = 0b1, .W = 0b0, .L = 0b1,
            .regn = 0b1000,
            .reglist = 0b10110111_01001000,
        }};
    try testing.expectEqual(expected, inst);
}
