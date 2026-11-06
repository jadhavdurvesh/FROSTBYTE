const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const core = b.addModule("frostbyte", .{ .root_source_file = b.path("src/frostbyte.zig"), .target = target, .optimize = optimize });
    const server = b.addExecutable(.{ .name = "frostbyte", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });
    server.root_module.addImport("frostbyte", core);
    b.installArtifact(server);
    const run_cmd = b.addRunArtifact(server);
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run the FROSTBYTE framed TCP echo server").dependOn(&run_cmd.step);
    const tests = b.addTest(.{ .root_source_file = b.path("src/frostbyte.zig"), .target = target, .optimize = optimize });
    b.step("test", "Run protocol and buffer tests").dependOn(&b.addRunArtifact(tests).step);
}
