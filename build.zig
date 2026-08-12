const std = @import("std");
const LazyPath = std.Build.LazyPath;

// pub const Options = struct {
//     optimize: union(enum) {
//         /// Slower decompression but smallest size
//         size,
//         /// Fastest decompression but not smallest size
//         performance,
//         explicit: enum { deflate, lzma, brotli, zstd },
//     },
// };

pub fn create(project: *std.Build, dir: LazyPath) *std.Build.Module {
    const embed_dep = project.dependencyFromBuildZig(@This(), .{
        .optimize = .ReleaseFast,
    });

    const embed_exe = embed_dep.artifact("akane-embed");
    const run_embed = project.addRunArtifact(embed_exe);
    const generated_root_file = run_embed.addOutputFileArg("akane_embed_bundle.zig");
    const compressed_data_file = run_embed.addOutputFileArg("data.bin");
    run_embed.addDirectoryArg(dir);

    const bundle_module = project.createModule(.{
        .root_source_file = generated_root_file,
    });

    bundle_module.addImport("akane_embed", embed_dep.module("akane_embed"));
    bundle_module.addImport("compressed_data", project.createModule(.{
        .root_source_file = compressed_data_file,
    }));

    return bundle_module;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("akane_embed", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "akane-embed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const test_step = b.step("test", "run tests");

    const api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_api_tests = b.addRunArtifact(api_tests);
    test_step.dependOn(&run_api_tests.step);

    setupSnapshotTests(b, test_step);
}

fn setupSnapshotTests(b: *std.Build, test_step: *std.Build.Step) void {
    const run_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "run" });
    run_build.has_side_effects = true;
    run_build.setCwd(b.path("tests/simple"));
    test_step.dependOn(&run_build.step);
}
