const std = @import("std");
const builtin = @import("builtin");
const sketch = @import("sketch.zig");
const spiral = @import("spiral.zig");
const crossed = @import("crosshatch.zig");
const clap = @import("clap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    var options = try std.process.ArgIterator.initWithAllocator(alloc);
    defer options.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-f, --filter <filter>      An option parameter, which takes a value.
        \\-i, --input <file>      An option parameter, which takes a value.
        \\-o, --output <file>     An option parameter, which takes a value.
        \\--linewidth <float>    An option parameter, which takes a value.
        \\--nibsize <float>      An option parameter, which takes a value.
        \\--width <float>        An option parameter, which takes a value.
        // \\-c, --color <hex_code> An option parameter, which takes a value.
        \\-s, --scale <float>    An option parameter, which takes a value.
        \\-t, --sigtransform <float> <float> <float> An option parameter, which takes a value.
        \\--preview-svg <bool>         An option parameter, which takes a value.
        \\--preview-png <bool>         An option parameter, which takes a value.
        \\--levels <int>... An option parameter, which takes a value.
        \\--linespacing <int>    An option parameter, which takes a value.
        \\-r, --round  <bool>          An option parameter, which takes a value.
        \\-S, --internallinesize <int> An option parameter, which takes a value.
        \\-m, --maxlinelength <int>  An option parameter, which takes a value.
        \\
    );
    const Filter = enum {
        all,
        sketchy,
        spiral,
        crossed,
    };
    const parsers = comptime .{
        .bool = clap.parsers.int(u1, 10),
        .float = clap.parsers.float(f32),
        .str = clap.parsers.string,
        .file = clap.parsers.string,
        .int = clap.parsers.int(usize, 10),
        .filter = clap.parsers.enumeration(Filter),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
    const filter = if (res.args.filter) |f| f else Filter.all;
    if (res.args.input) |s|
        std.debug.print("--input = {any}\n", .{s});

    std.debug.print("Filter: {s}\n", .{@tagName(filter)});

    var filename: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    while (options.next()) |arg| {
        if (std.mem.eql(u8, arg, "-i")) {
            filename = options.next() orelse return error.InvalidArg;
            std.debug.print("Input image: {s}\n", .{filename.?});
        }
        if (std.mem.eql(u8, arg, "-o")) {
            output = options.next() orelse return error.InvalidArg;
            std.debug.print("Ouput file(s): {s}\n", .{output.?});
        }
    }
    if (filename == null or output == null) return error.InvalidArg;
    var buf: [1024]u8 = undefined;
    var output_file: []const u8 = undefined;

    if (filter == .all or filter == .sketchy) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "sketch" });
        try sketch.sketch(filename.?, output_file);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (filter == .all or filter == .spiral) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "spiral" });
        try spiral.spiral(filename.?, output_file);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (filter == .all or filter == .crossed) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "crossed" });
        try crossed.crossed(filename.?, output_file);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
}
