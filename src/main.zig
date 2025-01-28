const std = @import("std");
const builtin = @import("builtin");
const sketchy = @cImport(@cInclude("SketchyImage.h"));
const coords_large = @import("crossed.zig").large;
const coords_xlarge = @import("crossed.zig").xlarge;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    var options = try std.process.ArgIterator.initWithAllocator(alloc);
    var filename: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    while (options.next()) |arg| {
        if (std.mem.eql(u8, arg, "-i")) {
            filename = options.next() orelse return error.InvalidArg;
            std.debug.print("Input image: {s}\n", .{filename.?});
        }
        if (std.mem.eql(u8, arg, "-o")) {
            output = options.next() orelse return error.InvalidArg;
            std.debug.print("Ouput file: {s}\n", .{output.?});
        }
    }
    if (filename == null or output == null) return error.InvalidArg;
    // try sketch(filename.?, output.?);
    try spiral(filename.?, output.?);

    options.deinit();
}

pub fn spiral(filename: []const u8, output_file: []const u8) !void {
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
    const color = "black";
    const nibsize = 1;
    const scale = 1.0;
    const sigTransX = 0.0;
    const sigTransY = 0.0;
    const sigScale = 1.0;

    const level0 = 50;
    const level1 = 100;
    const level2 = 150;
    const level3 = 200;

    sketchy.SketchyImage_setNibSize(img, nibsize);

    var svgFile = try std.fs.cwd().createFile(
        output_file,
        .{},
    );
    defer svgFile.close();
    var writer = svgFile.writer();

    const extraHeight = if (sigScale == 0.0) 0 else 100;
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

    const levels: [4]i16 = .{ level0, level1, level2, level3 };

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

        if (pixelvalue < levels[level_id]) {
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

pub fn crossed(filename: []const u8, output_file: []const u8) !void {
    const nibsize = 1;
    const scale = 1.0;
    const level0 = 50;
    const level1 = 100;
    const level2 = 150;
    const level3 = 200;
    const typ = 1;
    const sigTransX = 0.0;
    const sigTransY = 0.0;
    const sigScale = 1.0;

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
    var threshold: i16 = level0;
    var newstate: i16 = 1;
    var penstate: i16 = -1;
    var pixelvalue: c_int = 0;
    var layerIndex: usize = 0;
    var radius: f32 = 0.0;

    const levels: [4]i16 = .{ level0, level1, level2, level3 };

    var svgFile = try std.fs.cwd().createFile(
        output_file,
        .{},
    );
    defer svgFile.close();
    var writer = svgFile.writer();
    const extraHeight = if (sigScale == 0.0) 0 else 100;
    try writer.print(
        svg_formatstring[0 .. svg_formatstring.len - 18],
        .{
            "100%",
            "100%",
            @as(f32, @floatFromInt(width)) * scale,
            @as(f32, @floatFromInt(height + extraHeight)) * scale,
            @as(f32, @floatFromInt(width)) * scale,
            @as(f32, @floatFromInt(height + extraHeight)) * scale,
            scale,
        },
    );
    const coords = if (typ == 1) coords_large else coords_xlarge;
    var i: usize = 0;
    while (i < coords.len) : (i += 2) {
        if (coords[i] == -20) {
            layerIndex += 1;
            threshold = levels[layerIndex];
        } else if (coords[i] == -10) {
            radius = @as(f32, @floatFromInt(coords[i + 1])) / 10.0;
            newstate = 0;
            if (newstate != penstate) {
                to_x = x;
                to_y = y;
                try appendsegment(writer, from_x, from_y, to_x, to_y, radius, color, nibsize, 1);
            }
            penstate = newstate;
        } else {
            x = @as(f32, @floatFromInt(coords[i])) / 10.0;
            y = @as(f32, @floatFromInt(coords[i + 1])) / 10.0;
            pixelvalue = sketchy.SketchyImage_getPixel(
                img,
                @intFromFloat(x),
                @intFromFloat(y),
            );
            if (pixelvalue < threshold) {
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

pub fn sketch(filename: []const u8, output_file: []const u8) !void {
    const obj = sketchy.SketchyImage_allocWithFileName(filename.ptr);
    if (obj == null) {
        std.debug.print("Failed to load image\n", .{});
        return error.FailedToLoadImage;
    }
    defer sketchy.SketchyImage_release(obj);

    // std.debug.print("Loaded image {any}\n", .{obj.*.type.*});

    const nibsize = 1;
    const linesize = 1;
    const maxLineLength = 50;
    const scale = 1.0;
    const sigTransX = 0.0;
    _ = sigTransX; // autofix
    const sigTransY = 0.0;
    _ = sigTransY; // autofix
    const sigScale = 1.0;
    const color = "black";
    const sig = "Signature";

    sketchy.SketchyImage_setNibSize(obj, linesize);
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

    const extraHeight = if (sigScale == 0.0) 0 else 100;

    try writer.print(
        svg_formatstring,
        .{
            "100%",
            "100%",
            @as(f32, @floatFromInt(width)) * scale,
            @as(f32, @floatFromInt(height + extraHeight)) * scale,
            @as(f32, @floatFromInt(width)) * scale,
            @as(f32, @floatFromInt(height + extraHeight)) * scale,
            scale,
        },
    );

    var random = std.rand.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    var rand = random.random();

    while (outputBrightness > threshold) {
        const r = 10 + @mod(rand.int(i32), maxLineLength);
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

    // try writer.print(signature, .{ sigTransX, sigTransY, sigScale, color });

    try writer.print("\" style=\"fill:none;stroke:{s};stroke-width:{d:0.2};stroke-linecap:round;stroke-linejoin:round;\" />{s}", .{ color, nibsize, sig });
    try writer.writeAll(
        "</g></svg>\n",
    );

    // char rsvgCommand[200];
    // int rsvg_command_status = sprintf(rsvgCommand, "rsvg-convert -a -w 1000 %s -o %s.png --background-color '#ffffff'", output_filename, output_filename);
    // if(rsvg_command_status){
    //     system(rsvgCommand);
    // }
}

const svg_formatstring =
    \\<?xml version="1.0" encoding="utf-8"?>
    \\<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"> 
    \\<svg version="1.1"
    \\ id="Layer_1"
    \\ xmlns="http://www.w3.org/2000/svg"
    \\ xmlns:xlink="http://www.w3.org/1999/xlink"
    \\ x="0px"
    \\ y="0px"
    \\ width="{s}"
    \\ height="{s}"
    \\ viewBox="0 0 {d:0.2} {d:0.2}"
    \\ enable-background="new 0 0 {d:0.2} {d:0.2}"
    \\ xml:space="preserve">
    \\ <g transform="scale({d:0.2})">
    \\<polyline points="
;
const signature = "<g transform=\"translate({d:0.2}, {d:0.2}) scale({d:0.2})\"><g transform=\"scale(0.3 0.3)\"><defs><style type=\"text/css\"><![CDATA[.sig {{stroke: {s} }}]]></style></defs><path class=\"sig\" d=\"M69.924,10.776L42.823,252.867C42.823,252.867 52.57,194.932 54.117,154.803C55.663,114.673 39.811,113.148 19.908,113.444C0.004,113.74 124.589,113.444 124.589,113.444C124.589,113.444 89.908,122.899 94.421,82.966C98.934,43.033 101.533,10.776 101.533,10.776L78.377,252.867L88.405,154.803C88.405,154.803 90.436,140.75 118.641,139.843C146.846,138.937 15.204,139.843 15.532,139.843C15.86,139.843 25.342,139.843 25.342,139.843\" fill=\"none\" stroke=\"red\" stroke-width=\"15\" transform=\"translate(200, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.5,0.1c0,0 28.35,239.417 43.1,261.2c14.75,21.783 30.483,-130.5 45.4,-130.5c14.917,0 29.45,152.283 44.1,130.5c14.65,-21.783 43.8,-261.2 43.8,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(400, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.96,262.3l75.3,-251.7c4.35,-12.8 22.45,-12.8 26.79,0l75.3,251.7c0,0 -15.762,-108.242 -38.85,-129.89c-23.088,-21.648 -99.68,0 -99.68,0\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(600, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M5.264,3.677c0,74.899 -10.019,198.896 17.474,239.586c27.493,40.691 147.482,4.557 147.482,4.557\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(800, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M5.264,3.677c0,74.899 -10.019,198.896 17.474,239.586c27.493,40.691 147.482,4.557 147.482,4.557\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1000, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M12.993,8.183c0,0 -25.381,186.489 0,223.787c25.382,37.298 126.908,37.298 152.289,0c25.381,-37.298 0,-223.787 0,-223.787\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1200, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.4,0.3l176.4,261.2c0,0 -58.5,-130.1 -87.9,-130.1c-29.4,0 -88.5,130.1 -88.5,130.1l176.4,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1400, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.4,0.3l176.4,261.2c0,0 -58.5,-130.1 -87.9,-130.1c-29.4,0 -88.5,130.1 -88.5,130.1l176.4,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1600, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1800, 350)\"/></g></g>";
