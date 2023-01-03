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
        var empty = TileSetType.initFull();
        if (self == .blank and direction == .left) {
            empty.unset(@enumToInt(TileSet.left));
        } else if (self == .blank and direction == .right) {
            empty.unset(@enumToInt(TileSet.right));
        } else if (self == .left and direction == .left) {
            empty.unset(@enumToInt(TileSet.left));
        } else if (self == .left and direction == .right) {
            empty.unset(@enumToInt(TileSet.left));
            empty.unset(@enumToInt(TileSet.blank));
        } else if (self == .right and direction == .left) {
            empty.unset(@enumToInt(TileSet.right));
            empty.unset(@enumToInt(TileSet.blank));
        } else if (self == .right and direction == .right) {
            empty.unset(@enumToInt(TileSet.right));
        }
        return empty;
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
