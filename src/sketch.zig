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

pub fn sketch(opts: FilterOptions) !void {
    const filename = opts.input;
    const output_file = opts.output;
    const obj = sketchy.SketchyImage_allocWithFileName(filename.ptr);
    if (obj == null) {
        std.debug.print("Failed to load image\n", .{});
        return error.FailedToLoadImage;
    }
    defer sketchy.SketchyImage_release(obj);

    // std.debug.print("Loaded image {any}\n", .{obj.*.type.*});

    const nibsize = opts.nibsize_mm;
    _ = nibsize; // autofix
    const linesize = opts.linewidth;
    const maxLineLength = opts.max_line_length;
    const scale = opts.scale;
    const sigTransX = opts.signature.x;
    const sigTransY = opts.signature.y;
    const sigScale = opts.signature.scale;
    const color = opts.color;

    sketchy.SketchyImage_setNibSize(obj, @intFromFloat(linesize));
    const avg = sketchy.SketchyImage_getAvgBrightness(obj); // 0-255
    var threshold = sketchy.SketchyImage_getBrightness(obj);
    // std.debug.print("Avg Brightness: {}\nThreshold:{}\n", .{ avg, threshold });
    if (avg < 128) {
        threshold = @intFromFloat(@as(f32, @floatFromInt(threshold)) * (128.0 / avg));
    }
    var outputBrightness = sketchy.SketchyImage_getOutputBrightness(obj);
    const width = sketchy.SketchyImage_getCanvasWidth(obj);
    const height = sketchy.SketchyImage_getCanvasHeight(obj);
    // std.debug.print("Output Brightness: {}\nWidth:{}\nHeight:{}\n", .{ outputBrightness, width, height });

    const darkestPixel: *sketchy.Point = sketchy.SketchyImage_getDarkPixel(obj);
    defer sketchy.Point_release(darkestPixel);
    // std.debug.print("Darkest pixel: {}\n", .{darkestPixel});

    var x = darkestPixel.x;
    var y = darkestPixel.y;

    var svgFile = try std.fs.cwd().createFile(
        output_file,
        .{},
    );
    defer svgFile.close();

    var writer = svgFile.writer();

    const extraHeight: f32 = if (sigScale == 0.0) 0 else 100;

    try writer.print(
        svg_formatstring,
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

    var random = std.rand.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    var rand = random.random();

    while (outputBrightness > threshold) {
        const r = 10 + @mod(rand.int(i32), @as(i32, @intFromFloat(maxLineLength)));
        const p: *sketchy.Point = sketchy.SketchyImage_bestPointOfNDestinationsFromXY2(
            obj,
            r,
            @intFromFloat(x),
            @intFromFloat(y),
        );
        outputBrightness = sketchy.SketchyImage_getOutputBrightness(obj);

        try writer.print("{d:0},{d:0} ", .{ x, y });
        x = p.x;
        y = p.y;
    }
    try writer.writeAll("\" style=\"fill:none;stroke:black;stroke-width:1;stroke-linecap:round;stroke-linejoin:round;\"/>");

    var buf: [80_000:0]u8 = undefined;
    @memset(&buf, 0);
    const sig = try std.fmt.bufPrint(&buf, signature, .{
        sigTransX,
        sigTransY,
        sigScale,
        color,
    });
    try writer.print("{s}</g></svg>\n", .{sig});

    // char rsvgCommand[200];
    // int rsvg_command_status = sprintf(rsvgCommand, "rsvg-convert -a -w 1000 %s -o %s.png --background-color '#ffffff'", output_filename, output_filename);
    // if(rsvg_command_status){
    //     system(rsvgCommand);
    // }
}
