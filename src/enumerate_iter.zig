const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that yields the current count and the element during iteration.
///
/// See `enumerate` for more info.
pub fn EnumerateIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        count: usize,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Self.Item else ?Self.Item;
        pub const Item = struct {
            item: itertools.Item(BaseIter),
            index: usize,
        };

        pub fn next(self: *Self) Next {
            const has_error = IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            self.count += 1;
            return .{
                .item = item,
                .index = self.count - 1,
            };
        }
    };
}

/// Creates an iterator which gives the current iteration count as well as
/// the next value.
///
/// The iterator returned yields structs `.{ .index = i, .item = val }`, where `i` is the
/// current index of iteration and `val` is the value returned by the
/// iterator.
///
/// # Overflow Behavior
///
/// The method does no guarding against overflows, so enumerating more than
/// `std.math.maxInt(usize)` elements produces safety checked undefined behavior.
pub fn enumerate(iter: anytype) EnumerateIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .count = 0 };
}

test "enumerate" {
    var base_iter = range(u32, 5, 10).stepBy(2);
    var iter = enumerate(base_iter);
    try testing.expectEqual(@TypeOf(iter).Item, Item(@TypeOf(iter)));
    const v1 = iter.next().?;
    try testing.expectEqual(@as(u32, v1.item), 5);
    try testing.expectEqual(@as(usize, v1.index), 0);
    const v2 = iter.next().?;
    try testing.expectEqual(@as(u32, v2.item), 7);
    try testing.expectEqual(@as(usize, v2.index), 1);
    const v3 = iter.next().?;
    try testing.expectEqual(@as(u32, v3.item), 9);
    try testing.expectEqual(@as(usize, v3.index), 2);
    try testing.expectEqual(@as(?@TypeOf(iter).Item, null), iter.next());
}
