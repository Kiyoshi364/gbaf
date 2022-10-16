const std = @import("std");
const asmi = @import("asm.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const alloc = gpa.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const buffer = try alloc.alloc(u8, 0xFF_FF);
    defer alloc.free(buffer);

    const isArm = true;
    const isBigEndian = true;

    var read = @as(usize, 1);
    var flip: if (isArm) u2 else u1 = 0;
    const flipMax = @as(@TypeOf(flip), 0) -% 1;
    var acc: if (isArm) u32 else u16 = 0;
    while ( read > 0 ) {
        read = try stdin.read(buffer);
        for (buffer[0..read]) |c| {
            const Int = if (isArm) u5 else u4;
            const shiftBig    = 8 * @as(Int, flipMax - flip);
            const shiftLittle = 8 * @as(Int, flip);
            const shift = if (isBigEndian) shiftBig else shiftLittle;
            acc |= @as(@TypeOf(acc), c) << shift;

            flip +%= 1;
            if ( flip == 0 ) {
                acc |= c;
                if (isArm) {
                    try std.fmt.format(stdout,
                        "0x{X:0>8}: ", .{ acc });
                    const inst = asmi.Arm.from_int(acc);
                    try inst.debug_print(stdout);
                } else {
                    try std.fmt.format(stdout,
                        "0x{X:0>4}: ", .{ acc });
                    const inst = asmi.Thumb.from_int(acc);
                    try inst.debug_print(stdout);
                }
                acc = 0;
            }
        }
    }
}
