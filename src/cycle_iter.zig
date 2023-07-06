const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that repeats endlessly.
///
/// See `cycle` for more info.
pub fn CycleIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        orig_iter: BaseIter,
        base_iter: BaseIter,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;

            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();

            if (maybe_item) |item| {
                return item;
            } else {
                self.base_iter = self.orig_iter;
                return if (has_error)
                    try self.base_iter.next()
                else
                    self.base_iter.next();
            }
        }
    };
}

/// Repeats an iterator endlessly.
///
/// Instead of stopping at None, the iterator will instead start again, from the
/// beginning. After iterating again, it will start at the beginning again.
/// And again. And again. Forever. Note that in case the original iterator is
/// empty, the resulting iterator will also be empty.
pub fn cycle(iter: anytype) CycleIter(@TypeOf(iter)) {
    return .{ .orig_iter = iter, .base_iter = iter };
}

test "Cycle" {
    var base_iter = range(u32, 0, 3);
    var iter = cycle(base_iter);
    try std.testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
}
