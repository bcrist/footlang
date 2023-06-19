const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    //[[!! include 'build' !! 28 ]]
    //[[ ################# !! GENERATED CODE -- DO NOT MODIFY !! ################# ]]

    const dep__Zig_TempAllocator = b.dependency("Zig-TempAllocator", .{});

    const TempAllocator = dep__Zig_TempAllocator.module("TempAllocator");

    const verdic = b.addExecutable(.{
        .name = "verdic",
        .root_source_file = .{ .path = "src/verdic.zig" },
        .target = target,
        .optimize = mode,
    });
    verdic.addModule("TempAllocator", TempAllocator);
    b.installArtifact(verdic);
    _ = makeRunStep(b, verdic, "verdic", "Run verdic");

    const tests1 = b.addTest(.{
        .root_source_file = .{ .path = "src/Token.zig"},
        .target = target,
        .optimize = mode,
    });
    const run_tests1 = b.addRunArtifact(tests1);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests1.step);

    //[[ ######################### END OF GENERATED CODE ######################### ]]
}

fn makeRunStep(b: *std.build.Builder, exe: *std.build.CompileStep, name: []const u8, desc: []const u8) *std.build.RunStep {
    var run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    b.step(name, desc).dependOn(&run.step);
    return run;
}
