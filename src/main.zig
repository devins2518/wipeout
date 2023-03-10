const std = @import("std");

pub const Direction = enum {
    up,
    left,
    right,
    down,
};

pub fn TileBitSetTy(comptime E: type) type {
    const EInfo = @typeInfo(E);
    if (EInfo != .Enum) @compileError("TilesTy should be an enum.");
    return std.bit_set.StaticBitSet(EInfo.Enum.fields.len);
}

pub fn Collapser(
    comptime TilesTy: type,
    comptime height: usize,
    comptime width: usize,
    comptime Callback: ?fn (collapser: anytype) void,
) type {
    const TilesLen = height * width;
    return struct {
        const Self = @This();
        const CollapsedTy = std.bit_set.StaticBitSet(TilesLen);
        const CollapsedTyFull = CollapsedTy.initFull();
        const TileSetTy = TileBitSetTy(TilesTy);

        collapsed: CollapsedTy = CollapsedTy.initEmpty(),
        entropy: [TilesLen]TileSetTy = [_]TileSetTy{TileSetTy.initFull()} ** TilesLen,
        tiles: [TilesLen]TilesTy = [_]TilesTy{undefined} ** TilesLen,
        // Is this ok?
        rand: std.rand.DefaultPrng = std.rand.DefaultPrng.init(0),

        pub fn init() Self {
            return Self{ .rand = std.rand.DefaultPrng.init(@bitCast(u64, std.time.timestamp())) };
        }

        pub fn collapse(self: *Self) [TilesLen]TilesTy {
            while (!self.collapsed.eql(CollapsedTyFull)) {
                self.collapseNext();
                if (Callback) |C|
                    C(self);
            }
            return self.tiles;
        }
        fn collapseNext(self: *Self) void {
            // Find tile with least entropy
            const idx = self.findIdxOfLeastEntropyOrRandUncollapsedTile();
            // Get value to assign to tile
            const val = if (self.entropy[idx].count() == 1)
                @intToEnum(TilesTy, self.entropy[idx].findFirstSet().?)
            else
                self.getRandTile(self.entropy[idx]);
            // Assign to tile and update entropy
            self.collapseTile(idx, val);
        }
        fn findIdxOfLeastEntropyOrRandUncollapsedTile(self: *Self) usize {
            // If this function is called on a collapsed set, something else has gone wrong.
            var idx_of_min: usize = for (self.entropy) |e, i| {
                if (e.count() != 0) break i;
            } else unreachable;
            var count_of_min = self.entropy[idx_of_min].count();
            var duplicate = false;
            const starting_idx = idx_of_min + 1;
            for (self.entropy[starting_idx..]) |e, idx| {
                const e_count = e.count();
                if (e_count == 0) {
                    continue;
                } else if (e_count < count_of_min) {
                    idx_of_min = idx + starting_idx;
                    count_of_min = e_count;
                    duplicate = false;
                } else if (e_count == count_of_min) {
                    duplicate = true;
                }
            }
            if (duplicate) {
                idx_of_min = while (true) {
                    const idx = self.getRandUncollapsedTile();
                    if (self.entropy[idx].count() == count_of_min) break idx;
                };
            }
            std.log.info("Choosing idx_of_min: {} with entropy: {}. Duplicate: {}", .{ idx_of_min, count_of_min, duplicate });
            return idx_of_min;
        }
        fn getRandTile(self: *Self, entropy: TileSetTy) TilesTy {
            while (true) {
                const gen = self.rand.random().enumValue(TilesTy);
                if (entropy.isSet(@enumToInt(gen))) return gen;
            }
        }
        fn getRandUncollapsedTile(self: *Self) usize {
            while (true) {
                const gen = self.rand.random().int(usize) % TilesLen;
                if (!self.collapsed.isSet(gen)) return gen;
            }
        }
        fn updateEntropy(self: *Self, idx: usize, val: TilesTy) void {
            const conditions = blk: {
                var conditions = [_]bool{undefined} ** 4;
                conditions[@enumToInt(Direction.up)] = idx >= width;
                conditions[@enumToInt(Direction.left)] = idx % width != 0;
                conditions[@enumToInt(Direction.right)] = idx % width != width - 1;
                conditions[@enumToInt(Direction.down)] = idx + width < TilesLen;
                break :blk conditions;
            };
            const indexes = comptime blk: {
                var indexes = [_]usize{undefined} ** 4;
                indexes[@enumToInt(Direction.up)] = @bitCast(usize, -@intCast(isize, width));
                indexes[@enumToInt(Direction.left)] = @bitCast(usize, @as(isize, -1));
                indexes[@enumToInt(Direction.right)] = 1;
                indexes[@enumToInt(Direction.down)] = width;
                break :blk indexes;
            };

            self.entropy[idx] = TileSetTy.initEmpty();
            inline for ([_]Direction{ .up, .left, .right, .down }) |direction| {
                if (conditions[@enumToInt(direction)]) {
                    const valid_neighbors = val.getValidNeighbors(direction);
                    const offset_idx = idx +% indexes[@enumToInt(direction)];
                    self.entropy[offset_idx].setIntersection(valid_neighbors);
                }
            }
        }
        fn collapseTile(self: *Self, idx: usize, val: TilesTy) void {
            std.log.info("Collapsing tile: {} into {}\n", .{ idx, val });
            self.tiles[idx] = val;
            self.collapsed.set(idx);
            self.updateEntropy(idx, val);
        }
    };
}

const _TestTiles = enum(u8) {
    const _TestTilesSet = TileBitSetTy(_TestTiles);
    blank = 0,
    top_left = 1,
    bottom_left = 2,
    top_right = 3,
    bottom_right = 4,

    fn getValidNeighbors(self: _TestTiles, comptime direction: Direction) _TestTilesSet {
        var set = _TestTilesSet.initEmpty();
        if ((self == .top_right and direction == .left) or (self == .bottom_left and direction == .up))
            set.set(@enumToInt(_TestTiles.top_left))
        else if ((self == .top_left and direction == .right) or (self == .bottom_right and direction == .up))
            set.set(@enumToInt(_TestTiles.top_right))
        else if ((self == .bottom_right and direction == .left) or (self == .top_left and direction == .down))
            set.set(@enumToInt(_TestTiles.bottom_left))
        else if ((self == .bottom_left and direction == .right) or (self == .top_right and direction == .down))
            set.set(@enumToInt(_TestTiles.bottom_right));
        return set;
    }
};

test "idx of least entropy" {
    const C = Collapser(_TestTiles, 2, 2, null);
    const full = C.TileSetTy.initFull();
    const empty = C.TileSetTy.initEmpty();
    var one = C.TileSetTy.initEmpty();
    one.set(0);
    {
        var c = C{};
        c.entropy = .{
            one,
            full,
            empty,
            full,
        };
        try std.testing.expectEqual(@as(usize, 0), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
    {
        var c = C{};
        c.entropy = .{
            empty,
            one,
            full,
            full,
        };
        try std.testing.expectEqual(@as(usize, 1), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
    {
        var c = C{};
        c.entropy = .{
            full,
            one,
            empty,
            full,
        };
        try std.testing.expectEqual(@as(usize, 1), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
    {
        var c = C{};
        c.entropy = .{
            full,
            full,
            one,
            empty,
        };
        try std.testing.expectEqual(@as(usize, 2), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
    {
        var c = C{};
        c.entropy = .{
            full,
            empty,
            one,
            full,
        };
        try std.testing.expectEqual(@as(usize, 2), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
    {
        var c = C{};
        c.entropy = .{
            full,
            empty,
            full,
            one,
        };
        try std.testing.expectEqual(@as(usize, 3), c.findIdxOfLeastEntropyOrRandUncollapsedTile());
    }
}

test "update entropy" {
    const C = Collapser(_TestTiles, 2, 2, null);
    const empty = C.TileSetTy.initEmpty();
    const full = C.TileSetTy.initFull();
    const top_left = blk: {
        var top_left = C.TileSetTy.initEmpty();
        top_left.set(@enumToInt(_TestTiles.top_left));
        break :blk top_left;
    };
    const top_right = blk: {
        var top_right = C.TileSetTy.initEmpty();
        top_right.set(@enumToInt(_TestTiles.top_right));
        break :blk top_right;
    };
    const bottom_left = blk: {
        var bottom_left = C.TileSetTy.initEmpty();
        bottom_left.set(@enumToInt(_TestTiles.bottom_left));
        break :blk bottom_left;
    };
    const bottom_right = blk: {
        var bottom_right = C.TileSetTy.initEmpty();
        bottom_right.set(@enumToInt(_TestTiles.bottom_right));
        break :blk bottom_right;
    };
    {
        var c = C{};
        c.collapseTile(0, .top_left);
        try std.testing.expectEqual(
            [_]C.TileSetTy{
                empty,       top_right,
                bottom_left, full,
            },
            c.entropy,
        );
    }
    {
        var c = C{};
        c.collapseTile(1, .top_right);
        try std.testing.expectEqual(
            [_]C.TileSetTy{
                top_left, empty,
                full,     bottom_right,
            },
            c.entropy,
        );
    }
    {
        var c = C{};
        c.collapseTile(2, .bottom_left);
        try std.testing.expectEqual(
            [_]C.TileSetTy{
                top_left, full,
                empty,    bottom_right,
            },
            c.entropy,
        );
    }
    {
        var c = C{};
        c.collapseTile(3, .bottom_right);
        try std.testing.expectEqual(
            [_]C.TileSetTy{
                full,        top_right,
                bottom_left, empty,
            },
            c.entropy,
        );
    }
}
