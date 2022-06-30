const std = @import("std");
// const asmi = @import("asm.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const alloc = gpa.allocator();
    _ = alloc;
    // const inst = asmi.ArmInstruction.init(0).toAssembly(alloc);
    // std.log.info("{s}\n", .{ inst });
}
