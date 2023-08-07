const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that only iterates over the first n iterations of iter.
///
/// See `take` for more info.
pub fn TakeIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        to_take: usize,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = IterError(BaseIter) != null;
            if (self.to_take == 0) return null;
            self.to_take -= 1;
            return if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
        }
    };
}

/// Creates an iterator that yields the first n elements, or fewer if the
/// underlying iterator ends sooner.
///
/// `take(iter, n)` yields elements until n elements are yielded or the end of
/// the iterator is reached (whichever happens first). The returned iterator
/// is a prefix of length n if the original iterator contains at least n
/// elements, otherwise it contains all of the (fewer than n) elements of the
/// original iterator.
pub fn take(iter: anytype, to_take: usize) TakeIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .to_take = to_take };
}

test "take" {
    var base_iter = range(u32, 0, 10);
    var iter = take(base_iter, 5);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "take small iter" {
    var base_iter = range(u32, 0, 2);
    var iter = take(base_iter, 5);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
