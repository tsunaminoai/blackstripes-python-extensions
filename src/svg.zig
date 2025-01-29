/// a half hearted attempt at an svg builder thats not just print statements
pub const SVG = struct {
    width: f32,
    height: f32,

    groups: []const Group,

    pub const Path = struct {
        pub const Type = enum {
            line,
            arc,
            curve,
        };
        type: Type,
        start: Point,
        end: Point,
        radius: f32 = 1,
        direction: i32 = 1,
        fill: []const u8 = "none",
        color: []const u8 = "black",
        stroke_width: f32 = 1.0,
        stroke_linecap: []const u8 = "round",

        pub fn format(self: Path, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            switch (self.type) {
                .line => {
                    try writer.print("M{} ", .{self.start});
                    try writer.print("L{} ", .{self.end});
                },
                .arc => {
                    try writer.print("M{} ", .{self.start});
                    try writer.print("A{} 0 0,{d:0.0} {} ", .{ self.start, self.direction, self.end });
                },
                else => return error.UnhandledPathType,
            }
        }
    };
    pub const PolyPoints = struct {
        color: []const u8 = "black",
        size: f32 = 1.0,
        points: []const Point,
        pub fn format(self: PolyPoints, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            try writer.writeAll("<polyline points=\"");
            for (self.points) |p| try p.format("{}", .{}, writer);
            try writer.print(
                "\" style=\"fill:none;stroke:{s};stroke-width:{d:0.2};stroke-linecap:round;stroke-linejoin:round;\" />\n",
                .{ self.color, self.size },
            );
        }
    };
    pub const Node = union(enum) {
        poly: PolyPoints,
        path: Path,
        group: Group,
        pub fn format(self: Node, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            try switch (self) {
                else => |node| node.format("{}", .{}, writer),
            };
        }
    };
    pub const Group = struct {
        loc: Point = .{},
        scale: f32 = 1.0,
        color: []const u8 = "black",

        children: Array(Node),
        pub fn init(alloc: Allocator) Group {
            return .{ .children = Array(Node).init(alloc) };
        }
        pub fn addChild(self: *Group, child: Node) !Node {
            try self.children.append(child);
            return self.children.getLast();
        }
        pub fn format(self: Group, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            try writer.print(
                "<g transform=\"translate({});scale({d:0.2})\">\n",
                .{ self.loc, self.scale },
            );

            for (self.children.items) |child| {
                switch (child) {
                    .poly => |poly| try poly.format("{}", .{}, writer),
                    .path => |path| try path.format("{}", .{}, writer),
                    .group => |group| try group.format("{}", .{}, writer),
                }
            }

            try writer.writeAll("</g>\n");
        }
    };

    pub const Point = struct {
        x: i32 = 0,
        y: i32 = 0,
        pub fn format(self: Point, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            _ = fmt; // autofix
            _ = options; // autofix
            try writer.print("{d:0},{d:0} ", .{ self.x, self.y });
        }
    };

    pub fn format(self: SVG, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
        _ = fmt; // autofix
        _ = options; // autofix
        const header =
            \\<?xml version="1.0" encoding="utf-8"?>
            \\<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"> 
            \\<svg version="1.1"
            \\ id="Layer_1"
            \\ xmlns="http://www.w3.org/2000/svg"
            \\ xmlns:xlink="http://www.w3.org/1999/xlink"
            \\ x="0px"
            \\ y="0px"
            \\ width="{d:0.0}px"
            \\ height="{d:0.0}px"
            \\ viewBox="0 0 {d:0.2} {d:0.2}"
            \\ enable-background="new 0 0 {d:0.2} {d:0.2}"
            \\ xml:space="preserve">
            \\
        ;
        try writer.print(header, .{ self.width, self.height, self.height, self.height, self.width, self.height });
        for (self.groups) |group| {
            try group.format("{}", .{}, writer);
        }
        try writer.writeAll("</svg>\n");
    }

    pub const Builder = struct {
        svg: SVG,
        nodes: Array(Node),
        arena: std.heap.ArenaAllocator,
        root: Node,

        pub fn init(alloc: Allocator, height: f32, width: f32) !Builder {
            var nodes = Array(Node).init(alloc);
            try nodes.append(.{ .group = Group.init(alloc) });

            return Builder{
                .svg = .{ .width = width, .height = height, .groups = &.{} },
                .nodes = nodes,
                .arena = std.heap.ArenaAllocator.init(alloc),
                .root = nodes.items[0],
            };
        }
        pub fn deinit(self: *Builder) void {
            self.nodes.deinit();
        }
        pub fn format(self: Builder, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
            for (self.nodes.items) |n| {
                try n.format(fmt, options, writer);
            }
        }
    };
};
test {
    var s = try SVG.Builder.init(tst.allocator, 100, 100);
    defer s.deinit();

    const root = s.root;
    _ = root; // autofix

    // const svg = SVG{
    //     .width = 100.0,
    //     .height = 100.0,
    //     .groups = &[_]SVG.Group{
    //         SVG.Group{
    //             .loc = .{ .x = 10, .y = 10 },
    //             .scale = 1.0,
    //             .children = &.{
    //                 .{
    //                     .poly = .{
    //                         .color = "blue",
    //                         .size = 3.0,
    //                         .points = &[_]SVG.Point{
    //                             .{ .x = 0, .y = 0 },
    //                             .{ .x = 30, .y = 70 },
    //                             .{ .x = 100, .y = 100 },
    //                         },
    //                     },
    //                 },
    //             },
    //         },
    //     },
    // };
    const writer = std.io.getStdOut().writer();
    try s.format("{}", .{}, writer);
}
