const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zintake_module = b.addModule("zintake", .{
        .root_source_file = .{ .path = "src/zintake.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "example server",
        .root_source_file = .{ .path = "examples/server.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zintake", zintake_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
