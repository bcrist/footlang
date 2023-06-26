const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    //[[!! include 'build' !! 41 ]]
    //[[ ################# !! GENERATED CODE -- DO NOT MODIFY !! ################# ]]

    const Compiler = b.createModule(.{
        .source_file = .{ .path = "src/Compiler.zig" },
    });

    const dep__Zig_ConsoleHelper = b.dependency("Zig-ConsoleHelper", .{});

    const console = dep__Zig_ConsoleHelper.module("console");

    Compiler.dependencies.put("Compiler", Compiler) catch unreachable;
    Compiler.dependencies.put("console", console) catch unreachable;

    const dep__Zig_TempAllocator = b.dependency("Zig-TempAllocator", .{});

    const TempAllocator = dep__Zig_TempAllocator.module("TempAllocator");

    const foot = b.addExecutable(.{
        .name = "foot",
        .root_source_file = .{ .path = "src/foot.zig" },
        .target = target,
        .optimize = mode,
    });
    foot.addModule("Compiler", Compiler);
    foot.addModule("console", console);
    b.installArtifact(foot);
    _ = makeRunStep(b, foot, "foot", "Run foot");

    const tests1 = b.addTest(.{
        .root_source_file = .{ .path = "src/Token.zig"},
        .target = target,
        .optimize = mode,
    });
    const run_tests1 = b.addRunArtifact(tests1);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests1.step);

    _ = TempAllocator;
    //[[ ######################### END OF GENERATED CODE ######################### ]]
}

fn makeRunStep(b: *std.build.Builder, exe: *std.build.CompileStep, name: []const u8, desc: []const u8) *std.build.RunStep {
    var run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    b.step(name, desc).dependOn(&run.step);
    return run;
}
