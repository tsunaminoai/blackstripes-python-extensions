const std = @import("std");
const builtin = @import("builtin");
const sketch = @import("sketch.zig");
const spiral = @import("spiral.zig");
const crossed = @import("crosshatch.zig");
const clap = @import("clap");
const root = @import("root.zig");

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

    const parsers = comptime .{
        .bool = clap.parsers.int(u1, 10),
        .float = clap.parsers.float(f32),
        .str = clap.parsers.string,
        .file = clap.parsers.string,
        .int = clap.parsers.int(usize, 10),
        .filter = clap.parsers.enumeration(root.FilterOptions.FilterType),
    };

    var opts = root.FilterOptions{
        .input = undefined,
        .output = undefined,
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
    opts.filter = if (res.args.filter) |f| f else .all;
    opts.input = if (res.args.input) |s| s else return error.NoInputFile;
    opts.output = if (res.args.output) |s| s else return error.NoOutputFile;

    std.debug.print("Filter: {s}\n", .{@tagName(opts.filter)});

    var buf: [1024]u8 = undefined;
    var output_file: []const u8 = undefined;

    if (opts.filter == .all or opts.filter == .sketchy) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ opts.output, "sketch" });
        opts.output = output_file;

        try sketch.sketch(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (opts.filter == .all or opts.filter == .spiral) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ opts.output, "spiral" });
        opts.output = output_file;

        try spiral.spiral(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (opts.filter == .all or opts.filter == .crossed) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ opts.output, "crossed" });
        opts.output = output_file;
        try crossed.crossed(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
}
