const std = @import("std");
const Wipeout = @import("main.zig");
const Collapser = Wipeout.Collapser;
const Direction = Wipeout.Direction;
const TileSetTy = Wipeout.TileBitSetTy;

const TileSet = enum(u8) {
    const TileSetType = TileSetTy(@This());
    blank = 0,
    left = 1,
    right = 2,

    pub fn format(self: TileSet, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const block = switch (self) {
            .blank => "╋",
            .left => "┫",
            .right => "┣",
        };
        try std.fmt.format(writer, "{s}", .{block});
    }

    pub fn getValidNeighbors(self: @This(), comptime direction: Wipeout.Direction) TileSetType {
        const valid = comptime blk: {
            const TileSetInfo = @typeInfo(@This()).Enum;
            const DirectionInfo = @typeInfo(Direction).Enum;
            var valid: [TileSetInfo.fields.len][DirectionInfo.fields.len]TileSetType = undefined;
            const edges = [_][4][3]u1{
                // Blank
                [4][3]u1{
                    // Up
                    [_]u1{ 0, 1, 0 },
                    // Left
                    [_]u1{ 0, 1, 0 },
                    // Right
                    [_]u1{ 0, 1, 0 },
                    // Down
                    [_]u1{ 0, 1, 0 },
                },
                // Left
                [4][3]u1{
                    // Up
                    [_]u1{ 0, 1, 0 },
                    // Left
                    [_]u1{ 0, 1, 0 },
                    // Right
                    [_]u1{ 0, 0, 0 },
                    // Down
                    [_]u1{ 0, 1, 0 },
                },
                // Right
                [4][3]u1{
                    // Up
                    [_]u1{ 0, 1, 0 },
                    // Left
                    [_]u1{ 0, 0, 0 },
                    // Right
                    [_]u1{ 0, 1, 0 },
                    // Down
                    [_]u1{ 0, 1, 0 },
                },
            };
            for (std.enums.values(@This())) |_, e| {
                for ([_]Direction{ .up, .left, .right, .down }) |d| {
                    var valid_for_e_d = TileSetType.initEmpty();
                    const other_d: Direction = switch (d) {
                        .up => .down,
                        .left => .right,
                        .right => .left,
                        .down => .up,
                    };
                    for (edges) |other, i| {
                        const other_edge = other[@enumToInt(other_d)];
                        if (std.mem.eql(u1, &edges[e][@enumToInt(d)], &other_edge)) {
                            valid_for_e_d.set(i);
                        }
                    }
                    valid[e][@enumToInt(d)] = valid_for_e_d;
                }
            }
            break :blk valid;
        };
        return valid[@enumToInt(self)][@enumToInt(direction)];
    }
};

pub fn main() void {
    const h = 20;
    const w = 50;
    var c = Collapser(TileSet, h, w, null){};
    const tiles = c.collapse();
    for ([_]void{undefined} ** h) |_, y| {
        for ([_]void{undefined} ** w) |_, x| {
            std.debug.print("{}", .{tiles[y * w + x]});
        }
        std.debug.print("\n", .{});
    }
}

fn printTiles(collapser: anytype) void {
    const h = 20;
    const w = 50;
    const collapsed = @field(collapser, "collapsed");
    const tiles = @field(collapser, "tiles");
    for ([_]void{undefined} ** h) |_, y| {
        for ([_]void{undefined} ** w) |_, x| {
            const idx = y * w + x;
            if (collapsed.isSet(idx))
                std.debug.print("{}", .{tiles[idx]})
            else
                std.debug.print(" ", .{});
        }
        std.debug.print("\n", .{});
    }
}
