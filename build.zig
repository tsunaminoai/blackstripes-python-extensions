const std = @import("std");
const builtin = @import("builtin");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});
    const allocator = b.allocator;
    _ = allocator; // autofix

    const lib_lodepng = b.addSharedLibrary(.{
        .name = "lodepng",
        .target = target,
        .optimize = mode,
        .link_libc = true,
    });
    lib_lodepng.addCSourceFile(.{
        .file = b.path("./src/lib/lodepng/lodepng.c"),
        .flags = &.{
            "-DLODEPNG_COMPILE_PNG", // compile the code that writes and reads PNG files
            "-DLODEPNG_COMPILE_DISK", // compile the code that loads and saves files from disk
            "-DLODEPNG_COMPILE_MEMORY", // compile the code that loads and saves files from memory
            "-DLODEPNG_COMPILE_ZLIB", // compile the code that reads and writes zlib streams
            "-DLODEPNG_COMPILE_ENCODER", // compile the code that compresses and decompresses
            "-DLODEPNG_COMPILE_DECODER", // compile the code that decompresses and decompresses
            "-DLODEPNG_COMPILE_ANCILLARY_CHUNKS", // compile the code that handles ancillary chunks
            "-DLODEPNG_COMPILE_ALLOCATORS", // compile the code that handles memory allocation
        },
    });
    lib_lodepng.addIncludePath(b.path("./src/lib/lodepng"));
    b.installArtifact(lib_lodepng);

    const lib_sketchy = b.addSharedLibrary(.{
        .name = "sketchy",
        .target = target,
        .optimize = mode,
        .link_libc = true,
        .root_source_file = b.path("./src/root.zig"),
    });
    lib_sketchy.addCSourceFiles(.{
        .files = &.{
            "./src/lib/sketchy/SketchyImage.c",
            "./src/lib/sketchy/Point.c",
            "./src/lib/sketchy/FSArray.c",
            "./src/lib/sketchy/FSNumber.c",
            "./src/lib/sketchy/FSObject.c",
        },
        .flags = &.{},
    });
    lib_sketchy.addIncludePath(b.path("./src/lib/sketchy"));
    b.installArtifact(lib_sketchy);

    const out_libs = &.{
        "sketchy",
        "spiral",
        "crossed",
    };
    inline for (out_libs) |l| {
        const lib = b.addSharedLibrary(.{
            .name = l ++ ".cpython-312-" ++ @tagName(builtin.target.cpu.arch) ++ "-" ++ @tagName(builtin.target.os.tag),
            .target = target,
            .optimize = mode,
        });
        lib.addCSourceFile(.{
            .file = b.path("./src/blackstripes/" ++ l ++ ".c"),
            .flags = &.{},
        });

        lib.addIncludePath(b.path("./src/blackstripes"));
        lib.linkLibrary(lib_lodepng);
        lib.linkLibrary(lib_sketchy);
        lib.addSystemIncludePath(b.path(".devbox/nix/profile/default/include/python3.12/"));
        lib.addLibraryPath(b.path(".devbox/nix/profile/default/lib"));
        lib.linkSystemLibrary("python3.12");
        b.installArtifact(lib);
    }
    const exe = b.addExecutable(.{
        .name = "sketchy",
        .target = target,
        .optimize = mode,
        .link_libc = true,
        .root_source_file = b.path("./src/main.zig"),
    });
    exe.linkLibrary(lib_lodepng);
    exe.linkLibrary(lib_sketchy);
    exe.addIncludePath(b.path("./src/lib/lodepng"));
    exe.addIncludePath(b.path("./src/lib/sketchy"));
    b.installArtifact(exe);

    const runexe = b.addRunArtifact(exe);
    if (b.args) |a| {
        runexe.addArgs(a);
    }
    const runstep = b.step("run", "Run sketchy");
    runstep.dependOn(&runexe.step);
}
