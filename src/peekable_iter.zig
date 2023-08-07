const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;

/// An iterator with a peek() that returns an optional to the next element.
///
/// See `peekable` for more info.
pub fn PeekableIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        peeked: ??Item(BaseIter),

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            return if (self.peeked) |peeked| blk: {
                self.peeked = null;
                break :blk peeked;
            } else self.base_iter.next();
        }

        /// Returns the `next()` value without advancing the iterator.
        ///
        /// Like `next`, if there is a value, it is wrapped in an optional `?T`.
        /// But if the iteration is over, null is returned.
        pub fn peek(self: *Self) Next {
            if (self.peeked) |peeked| return peeked;

            const has_error = comptime IterError(BaseIter) != null;

            self.peeked = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();

            return self.peeked.?;
        }
    };
}

/// Creates an iterator which can use the `peek` method to look at the next
/// element of the iterator without consuming it. See its documentation for more information.
///
/// Note that the underlying iterator is still advanced when peek is called for
/// the first time: In order to retrieve the next element, next is called on
/// the underlying iterator, hence any side effects (i.e. anything other than
/// fetching the next value) of the next method will occur.
pub fn peekable(iter: anytype) PeekableIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .peeked = null };
}

test "Peekable" {
    var range = itertools.range(u32, 0, 5);
    var iter = peekable(range);
    try std.testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.peek());
    try testing.expectEqual(@as(?u32, 3), iter.peek());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.peek());
    try testing.expectEqual(@as(?u32, null), iter.peek());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
