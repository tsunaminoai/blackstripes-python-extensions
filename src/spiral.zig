const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const root = @import("root.zig");
const sketchy = root.sketchy;
const svg_formatstring = root.svg_formatstring;
const signature = root.signature;
const FilterOptions = root.FilterOptions;

pub fn spiral(opts: FilterOptions) !void {
    const filename = opts.input;
    const output_file = opts.output;
    const img = sketchy.SketchyImage_allocWithFileName(filename.ptr);
    if (img == null) {
        std.debug.print("Failed to load image\n", .{});
        return error.FailedToLoadImage;
    }
    defer sketchy.SketchyImage_release(img);

    const roundShapedSpiral = true;
    const linespacing = 1.0;

    const width: f32 = @floatFromInt(sketchy.SketchyImage_getCanvasWidth(img));
    const height: f32 = @floatFromInt(sketchy.SketchyImage_getCanvasHeight(img));
    const color = opts.color;
    const nibsize = opts.nibsize_mm;
    const scale = opts.scale;
    const sigTransX = opts.signature.x;
    const sigTransY = opts.signature.y;
    const sigScale = opts.signature.scale;

    sketchy.SketchyImage_setNibSize(img, @intFromFloat(nibsize));

    var svgFile = try std.fs.cwd().createFile(
        output_file,
        .{},
    );
    defer svgFile.close();
    var writer = svgFile.writer();

    const extraHeight: f32 = if (sigScale == 0.0) 0 else 100;
    try writer.print(
        svg_formatstring[0 .. svg_formatstring.len - 18],
        .{
            "100%",
            "100%",
            width * scale,
            (height + extraHeight) * scale,
            width * scale,
            (height + extraHeight) * scale,
            scale,
        },
    );

    var level_id: usize = 0;

    var x: f32 = 0;
    var y: f32 = 0;
    var from_x: f32 = 0;
    var from_y: f32 = 0;
    var to_x: f32 = 0;
    var to_y: f32 = 0;

    const levels = opts.levels;

    var i: usize = 0;
    var radius: f32 = if (roundShapedSpiral) width / 2 else @sqrt((width / 2.0) * (width / 2.0) + (height / 2.0) * (height / 2.0));

    const num_cycles: usize = @intFromFloat(radius / linespacing);
    const num_iterations = 3600 * num_cycles;

    const centerx = width / 2;
    const centery = height / 2;
    var pixelvalue: c_int = 0;

    var penstate: i16 = 0;
    var newstate: i16 = 0;
    var segment_iterations: usize = 0;
    const d2r = 0.0174532925;

    while (num_iterations > i) {
        if (@mod(i, 3600) == 0) {
            if (penstate == 1) {
                to_x = x;
                to_y = y;
                try appendCloseSegment(writer, to_x, to_y, radius, color, nibsize, segment_iterations);
            }
            radius -= linespacing;
            level_id += 1;
            if (level_id > levels.len - 1) level_id = 0;
        }
        x = @cos((@as(f32, @floatFromInt(i)) * d2r) / 10.0) * radius + centerx;
        y = @sin((@as(f32, @floatFromInt(i)) * d2r) / 10.0) * radius + centery;
        pixelvalue = if (x < 0 or x > width or y < 0 or y > height)
            999
        else
            sketchy.SketchyImage_getPixel(img, @intFromFloat(x), @intFromFloat(y));

        if (@as(f32, @floatFromInt(pixelvalue)) < levels[level_id]) {
            newstate = 1;
            if (newstate != penstate) {
                from_x = x;
                from_y = y;
                try appendOpenSegment(writer, from_x, from_y);
                segment_iterations = 0;
            }
            penstate = newstate;
        } else {
            newstate = 0;
            if (newstate != penstate) {
                to_x = x;
                to_y = y;
                try appendCloseSegment(writer, to_x, to_y, radius, color, nibsize, segment_iterations);
            }
            penstate = newstate;
        }
        i += 1;
        segment_iterations += 1;
    }

    var buf: [80_000:0]u8 = undefined;
    @memset(&buf, 0);
    const sig = try std.fmt.bufPrint(&buf, signature, .{
        sigTransX,
        sigTransY,
        sigScale,
        color,
    });
    try writer.print("{s}</g></svg>\n", .{sig});
}

inline fn appendOpenSegment(writer: anytype, fx: f32, fy: f32) !void {
    const svg_segment_format = "<path d=\"M{d:0.2},{d:0.2} ";
    try writer.print(svg_segment_format, .{ fx, fy });
}
inline fn appendCloseSegment(writer: anytype, tx: f32, ty: f32, radius: f32, color: []const u8, nib_size_mm: f32, segment_iterations: usize) !void {
    const svg_segment_format = "A{d:0.2},{d:0.2} 0 {d:0.0},{d:0.0} {d:0.2},{d:0.2}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:0.2}\" stroke-linecap=\"round\" />\n";
    const dir = 1;
    const long_way_home: usize = if (segment_iterations > 1800) 1 else 0;
    try writer.print(svg_segment_format, .{ radius, radius, long_way_home, dir, tx, ty, color, nib_size_mm });
}
