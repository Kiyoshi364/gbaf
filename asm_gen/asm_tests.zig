test "Thumb dummy instruction" {
    const inst = Thumb{ .AddSubRegister = .{
        .opcode = 1, .regm = 2, .regn = 4, .regd = 7,
    }};
    _ = inst;
}

test "Arm dummy instruction" {
    const inst = Arm{ .DataProcessingImmediateShift = .{
        .cond = 0, .opcode = 1, .S = 0, .regn = 2, .regd = 3,
        .shiftamount = 4, .shift = 2, .regm = 7,
    }};
    _ = inst;
}
