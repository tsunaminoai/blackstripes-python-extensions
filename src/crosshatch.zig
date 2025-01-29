const std = @import("std");
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
const tst = std.testing;
const math = std.math;

const root = @import("root.zig");
const sketchy = root.sketchy;
const svg_formatstring = root.svg_formatstring;
const signature = root.signature;
const coords_large = @import("crossed.zig").large;
const coords_xlarge = @import("crossed.zig").xlarge;
const FilterOptions = root.FilterOptions;

pub fn crossed(opts: FilterOptions) !void {
    const filename = opts.input;
    const output_file = opts.output;
    const nibsize = opts.nibsize_mm;
    const scale = opts.scale;

    const sigTransX = opts.signature.x;
    const sigTransY = opts.signature.y;
    const sigScale = opts.signature.scale;

    const img = sketchy.SketchyImage_allocWithFileName(filename.ptr);
    if (img == null) {
        std.debug.print("Failed to load image\n", .{});
        return error.FailedToLoadImage;
    }
    defer sketchy.SketchyImage_release(img);

    const width = sketchy.SketchyImage_getCanvasWidth(img);
    const height = sketchy.SketchyImage_getCanvasHeight(img);
    const color = "black";

    var x: f32 = 0;
    var y: f32 = 0;
    var to_x: f32 = 0;
    var to_y: f32 = 0;
    var from_x: f32 = 0;
    var from_y: f32 = 0;
    var threshold = opts.levels[0];
    var newstate: i16 = 1;
    var penstate: i16 = -1;
    var pixelvalue: c_int = 0;
    var layerIndex: usize = 0;
    var radius: f32 = 0.0;

    const levels = opts.levels;

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
            @as(f32, @floatFromInt(width)) * scale,
            (@as(f32, @floatFromInt(height)) + extraHeight) * scale,
            @as(f32, @floatFromInt(width)) * scale,
            (@as(f32, @floatFromInt(height)) + extraHeight) * scale,
            scale,
        },
    );
    const coords = switch (opts.crossed.size) {
        .large => coords_large,
        .xlarge => coords_xlarge,
    };
    var i: usize = 0;
    const diag: i32 = 0;
    _ = diag; // autofix
    const max_i = 4276284;
    _ = max_i; // autofix
    const max_diag = 9999;
    _ = max_diag; // autofix
    const start_radius = 282.0;
    _ = start_radius; // autofix
    const end_radius = 99.50;
    _ = end_radius; // autofix

    while (i < coords.len) : (i += 2) {
        // each value from 1 to 9999 occurs from 2379627x to 84x
        // this only happens 3 times at indicies out of 4276284
        // 2444449:-20,
        // 3055061:-20,
        // 3665673:-20,
        if (coords[i] == -20) {
            layerIndex += 1;
            threshold = levels[layerIndex];
        } else
        // beginning with index 1833841, -10 occues every other index
        if (coords[i] == -10) {
            radius = @as(f32, @floatFromInt(coords[i + 1])) / 10.0;
            newstate = 0;
            if (newstate != penstate) {
                to_x = x;
                to_y = y;
                try appendsegment(writer, from_x, from_y, to_x, to_y, radius, color, nibsize, 1);
            }
            penstate = newstate;
        } else {
            // this is just 0 to 9999
            x = @as(f32, @floatFromInt(coords[i])) / 10.0;
            y = @as(f32, @floatFromInt(coords[i + 1])) / 10.0;
            pixelvalue = sketchy.SketchyImage_getPixel(
                img,
                @intFromFloat(x),
                @intFromFloat(y),
            );
            if (@as(f32, @floatFromInt(pixelvalue)) < threshold) {
                newstate = 1;
                if (newstate != penstate) {
                    from_x = x;
                    from_y = y;
                }
                penstate = newstate;
            } else {
                newstate = 0;
                if (newstate != penstate) {
                    to_x = x;
                    to_y = y;
                    try appendsegment(writer, from_x, from_y, to_x, to_y, radius, color, nibsize, 1);
                }
                penstate = newstate;
            }
        }
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

inline fn appendsegment(writer: anytype, fx: f32, fy: f32, tx: f32, ty: f32, radius: f32, color: []const u8, nibsize_mm: f32, dir: i16) !void {
    // std.debug.print("appending.. ({},{})=>({},{})\n", .{ fx, fy, tx, ty });
    const svg_segment_format =
        \\<path d="M{d:0.2},{d:0.2}  A{d:0.2},{d:0.2} 0 0,{d:0.0} {d:0.2},{d:0.2}" fill="none" stroke="{s}" stroke-width="{d:0.2}" stroke-linecap="round" />
    ;
    try writer.print(svg_segment_format, .{ fx, fy, radius, radius, dir, tx, ty, color, nibsize_mm });
}
