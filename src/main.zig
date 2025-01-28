const std = @import("std");
const sketchy = @cImport(@cInclude("SketchyImage.h"));

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
const signature = "\"/></g><g transform=\"translate({d:0.2}, {d:0.2}) scale({d:0.2})\"><g transform=\"scale(0.3 0.3)\"><defs><style type=\"text/css\"><![CDATA[.sig {{stroke: {s} }}]]></style></defs><path class=\"sig\" d=\"M69.924,10.776L42.823,252.867C42.823,252.867 52.57,194.932 54.117,154.803C55.663,114.673 39.811,113.148 19.908,113.444C0.004,113.74 124.589,113.444 124.589,113.444C124.589,113.444 89.908,122.899 94.421,82.966C98.934,43.033 101.533,10.776 101.533,10.776L78.377,252.867L88.405,154.803C88.405,154.803 90.436,140.75 118.641,139.843C146.846,138.937 15.204,139.843 15.532,139.843C15.86,139.843 25.342,139.843 25.342,139.843\" fill=\"none\" stroke=\"red\" stroke-width=\"15\" transform=\"translate(200, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.5,0.1c0,0 28.35,239.417 43.1,261.2c14.75,21.783 30.483,-130.5 45.4,-130.5c14.917,0 29.45,152.283 44.1,130.5c14.65,-21.783 43.8,-261.2 43.8,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(400, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.96,262.3l75.3,-251.7c4.35,-12.8 22.45,-12.8 26.79,0l75.3,251.7c0,0 -15.762,-108.242 -38.85,-129.89c-23.088,-21.648 -99.68,0 -99.68,0\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(600, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M5.264,3.677c0,74.899 -10.019,198.896 17.474,239.586c27.493,40.691 147.482,4.557 147.482,4.557\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(800, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M5.264,3.677c0,74.899 -10.019,198.896 17.474,239.586c27.493,40.691 147.482,4.557 147.482,4.557\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1000, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M12.993,8.183c0,0 -25.381,186.489 0,223.787c25.382,37.298 126.908,37.298 152.289,0c25.381,-37.298 0,-223.787 0,-223.787\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1200, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.4,0.3l176.4,261.2c0,0 -58.5,-130.1 -87.9,-130.1c-29.4,0 -88.5,130.1 -88.5,130.1l176.4,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1400, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"M0.4,0.3l176.4,261.2c0,0 -58.5,-130.1 -87.9,-130.1c-29.4,0 -88.5,130.1 -88.5,130.1l176.4,-261.2\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1600, 350)\"/></g><g transform=\"scale(0.3 0.3)\"><path class=\"sig\" d=\"\" fill=\"none\" stroke=\"black\" stroke-width=\"15\" transform=\"translate(1800, 350)\"/></g></g>";

pub fn main() !void {
    const obj = sketchy.SketchyImage_allocWithFileName("test.png");
    if (obj == null) {
        std.debug.print("Failed to load image\n", .{});
        return error.FailedToLoadImage;
    }
    defer sketchy.SketchyImage_release(obj);

    std.debug.print("Loaded image {any}\n", .{obj.*.type.*});

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
    std.debug.print("Avg Brightness: {}\nThreshold:{}\n", .{ avg, threshold });
    if (avg < 128) {
        threshold = @intFromFloat(@as(f32, @floatFromInt(threshold)) * (128.0 / avg));
    }
    var outputBrightness = sketchy.SketchyImage_getOutputBrightness(obj);
    const width = sketchy.SketchyImage_getCanvasWidth(obj);
    const height = sketchy.SketchyImage_getCanvasHeight(obj);
    std.debug.print("Output Brightness: {}\nWidth:{}\nHeight:{}\n", .{ outputBrightness, width, height });

    const darkestPixel: *sketchy.Point = sketchy.SketchyImage_getDarkPixel(obj);
    defer sketchy.Point_release(darkestPixel);
    std.debug.print("Darkest pixel: {}\n", .{darkestPixel});

    var x = darkestPixel.x;
    var y = darkestPixel.y;

    const outputFilename = "test/output.svg";
    var svgFile = try std.fs.cwd().createFile(outputFilename, .{});
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

    var random = std.rand.DefaultPrng.init(0);
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
