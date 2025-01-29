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
        \\--threshold <float>    An option parameter, which takes a value.
        \\--nibsize <float>      An option parameter, which takes a value.
        \\--width <float>        An option parameter, which takes a value.
        // \\-c, --color <hex_code> An option parameter, which takes a value.
        \\-s, --scale <float>    An option parameter, which takes a value.
        \\-t, --sigtransform <float> <float> <float> An option parameter, which takes a value.
        \\--preview-svg <bool>         An option parameter, which takes a value.
        \\--preview-png <bool>         An option parameter, which takes a value.
        \\--levels <float>... An option parameter, which takes a value.
        \\--linespacing <int>    An option parameter, which takes a value.
        \\-r, --round  <bool>          An option parameter, which takes a value.
        \\-S, --internallinesize <float> An option parameter, which takes a value.
        \\-m, --maxlinelength <float>  An option parameter, which takes a value.
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
    opts.linewidth = if (res.args.linewidth) |f| f else opts.linewidth;
    opts.nibsize_mm = if (res.args.nibsize) |f| f else opts.nibsize_mm;
    opts.width = if (res.args.width) |f| f else opts.width;
    opts.scale = if (res.args.scale) |f| f else opts.scale;
    opts.signature.x = if (res.args.sigtransform) |f| f else opts.signature.x;
    opts.signature.y = if (res.args.sigtransform) |f| f else opts.signature.y;
    opts.signature.scale = if (res.args.sigtransform) |f| f else opts.signature.scale;
    opts.rounding = if (res.args.round == 1) true else opts.rounding;
    opts.internal_line_size = if (res.args.internallinesize) |f| f else opts.internal_line_size;
    opts.max_line_length = if (res.args.maxlinelength) |f| f else opts.max_line_length;
    opts.threshold = if (res.args.threshold) |f| f else opts.threshold;
    var levels: []f32 = undefined;
    if (res.args.levels.len > 0) {
        levels = try alloc.alloc(f32, res.args.levels.len);
        defer alloc.free(levels);

        for (res.args.levels, 0..) |*f, i| {
            levels[i] = f.*;
        }
        opts.levels = levels;
    }

    const output_original = opts.output;

    std.debug.print("Filter: {s}\n", .{@tagName(opts.filter)});

    var buf: [1024]u8 = undefined;
    var output_file: []const u8 = undefined;

    if (opts.filter == .all or opts.filter == .sketchy) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output_original, "sketch" });
        opts.output = output_file;

        try sketch.sketch(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (opts.filter == .all or opts.filter == .spiral) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output_original, "spiral" });
        opts.output = output_file;

        try spiral.spiral(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
    if (opts.filter == .all or opts.filter == .crossed) {
        output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output_original, "crossed" });
        opts.output = output_file;
        try crossed.crossed(opts);
        std.debug.print("Wrote: {s}\n", .{output_file});
    }
}
