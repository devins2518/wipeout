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

pub fn Collapser(comptime TilesTy: type, comptime height: usize, comptime width: usize) type {
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

        pub fn collapse(self: *Self) [TilesLen]TilesTy {
            while (!self.collapsed.eql(CollapsedTyFull)) {
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
            return self.tiles;
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
            self.entropy[idx] = TileSetTy.initEmpty();
            {
                const valid_neighbors = val.getValidNeighbors(.up);
                if (idx >= width)
                    self.entropy[idx - width] = valid_neighbors;
            }
            {
                const valid_neighbors = val.getValidNeighbors(.left);
                if (idx % width != 0)
                    self.entropy[idx - 1] = valid_neighbors;
            }
            {
                const valid_neighbors = val.getValidNeighbors(.right);
                if (idx % width != width - 1)
                    self.entropy[idx + 1] = valid_neighbors;
            }
            {
                const valid_neighbors = val.getValidNeighbors(.down);
                if (idx + width < TilesLen)
                    self.entropy[idx + width] = valid_neighbors;
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
        const empty = _TestTilesSet.initEmpty();
        var not_empty = _TestTilesSet.initEmpty();
        switch (self) {
            .blank => not_empty = _TestTilesSet.initFull(),
            .top_left => if (direction == .right)
                not_empty.set(@enumToInt(_TestTiles.top_right))
            else if (direction == .down)
                not_empty.set(@enumToInt(_TestTiles.bottom_left))
            else
                return empty,
            .bottom_left => if (direction == .right)
                not_empty.set(@enumToInt(_TestTiles.bottom_right))
            else if (direction == .up)
                not_empty.set(@enumToInt(_TestTiles.top_left))
            else
                return empty,
            .top_right => if (direction == .left)
                not_empty.set(@enumToInt(_TestTiles.top_left))
            else if (direction == .down)
                not_empty.set(@enumToInt(_TestTiles.bottom_right))
            else
                return empty,
            .bottom_right => if (direction == .left)
                not_empty.set(@enumToInt(_TestTiles.bottom_left))
            else if (direction == .up)
                not_empty.set(@enumToInt(_TestTiles.top_right))
            else
                return empty,
        }
        return not_empty;
    }
};

test "idx of least entropy" {
    const C = Collapser(_TestTiles, 2, 2);
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
    const C = Collapser(_TestTiles, 2, 2);
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
