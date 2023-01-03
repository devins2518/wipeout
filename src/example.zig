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

    pub fn getValidNeighbors(self: @This(), comptime direction: Wipeout.Direction) TileSetType {
        var empty = TileSetType.initEmpty();
        empty.set(@enumToInt(TileSet.blank));
        if (self == .blank or (self == .left and direction == .right))
            empty.set(@enumToInt(TileSet.right))
        else if (self == .blank or (self == .right and direction == .left))
            empty.set(@enumToInt(TileSet.left));
        return empty;
    }
};

pub fn main() void {
    var c = Collapser(TileSet, 2, 2){};
    const tiles = c.collapse();
    std.debug.print("{any}", .{tiles});
}
