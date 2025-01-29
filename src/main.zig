const std = @import("std");
const builtin = @import("builtin");
const sketch = @import("sketch.zig");
const spiral = @import("spiral.zig");
const crossed = @import("crosshatch.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    var options = try std.process.ArgIterator.initWithAllocator(alloc);
    defer options.deinit();
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
    var output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "sketch" });
    try sketch.sketch(filename.?, output_file);

    output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "spiral" });
    try spiral.spiral(filename.?, output_file);

    output_file = try std.fmt.bufPrint(&buf, "{s}-{s}.svg", .{ output.?, "crossed" });
    try crossed.crossed(filename.?, output_file);
}
