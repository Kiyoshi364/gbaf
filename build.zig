const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var all_tests = std.ArrayList(*std.build.Step).init(b.allocator);

    const asmgen_exe = b.addExecutable("asmgen", "asm_gen/gen.zig");
    asmgen_exe.setTarget(target);
    asmgen_exe.setBuildMode(mode);
    asmgen_exe.install();

    const asmgen_cmd = asmgen_exe.run();
    asmgen_cmd.step.dependOn(b.getInstallStep());

    const asmgen_step = b.step("gen", "Generate the asm.zig file");
    asmgen_step.dependOn(&asmgen_cmd.step);

    // Generated files
    const need_gen_arm_file =
        if ( std.fs.cwd().openFile("src/asm.zig", .{}) catch null )
            |file| blk: { defer file.close();
                break :blk
                    try isOlderThanAnyInDir(file, "asm_gen", b);
            }
        else true;

    const exe_asm_tests = b.addTest("src/asm.zig");
    exe_asm_tests.setTarget(target);
    exe_asm_tests.setBuildMode(mode);
    try all_tests.append(&exe_asm_tests.step);

    const test_asm_step = b.step("test_asm", "Run asm unit tests");
    if ( need_gen_arm_file ) {
        test_asm_step.dependOn(asmgen_step);
    }
    test_asm_step.dependOn(&exe_asm_tests.step);

    const exe = b.addExecutable("gbaf", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    if ( need_gen_arm_file ) {
        test_asm_step.dependOn(asmgen_step);
    }
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    try all_tests.append(&exe_tests.step);

    const test_exe_step = b.step("test_main", "Run main unit tests");
    if ( need_gen_arm_file) {
        test_asm_step.dependOn(asmgen_step);
    }
    test_exe_step.dependOn(&exe_tests.step);

    const test_step = b.step("test", "Run all unit tests");
    if ( need_gen_arm_file) {
        test_asm_step.dependOn(asmgen_step);
    }
    for ( all_tests.items ) |step| {
        test_step.dependOn(step);
    }
}

fn isOlderThanAnyInDir(file: std.fs.File, comptime dir_path: []const u8, b: *std.build.Builder) !bool {
    const ver = comptime try std.SemanticVersion.parse("0.10.0-dev.2489");
    const curr_ver = @import("builtin").zig_version;
    const is_new_ver = comptime curr_ver.order(ver) == .gt;
    if ( is_new_ver ) {
        return if ( file.stat() catch null ) |fstat| blk: {
            const itsubdir =
                try std.fs.cwd().openIterableDir(dir_path, .{});
            var walker = try itsubdir.walk(b.allocator);
            defer walker.deinit();
            break :blk while ( try walker.next() ) |entry| {
                if ( entry.kind == .File ) {
                    const curr_stat =
                            try itsubdir.dir.statFile(entry.basename);
                    if ( fstat.mtime < curr_stat.mtime ) {
                        break true;
                    }
                }
            } else false;
        } else false;
    } else {
        return if ( file.stat() catch null ) |fstat| blk: {
            const subdir =
                try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
            var walker = try subdir.walk(b.allocator);
            defer walker.deinit();
            break :blk while ( try walker.next() ) |entry| {
                if ( entry.kind == .File ) {
                    const curr_stat = try subdir.statFile(entry.basename);
                    if ( fstat.mtime < curr_stat.mtime ) {
                        break true;
                    }
                }
            } else false;
        } else false;
    }
}
