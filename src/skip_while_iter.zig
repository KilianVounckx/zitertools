const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that rejects elements while predicate returns true.
///
/// See `skipWhile` for more info.
pub fn SkipWhileIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        predicate: ?*const fn (Item(BaseIter)) bool,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = IterError(BaseIter) != null;
            if (self.predicate) |predicate| {
                self.predicate = null;
                while (true) {
                    const maybe_item = if (has_error)
                        try self.base_iter.next()
                    else
                        self.base_iter.next();
                    const item = maybe_item orelse return null;
                    if (!predicate(item)) return item;
                }
            }
            return if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
        }
    };
}

// Creates an iterator that skips elements based on a predicate.
//
// `skipWhile()` takes a function as an argument. It will call this function
/// on each element of the iterator, and ignore elements until it returns
/// false.
//
// After false is returned, `skipWhile()`’s job is over, and the rest of the
/// elements are yielded.
pub fn skipWhile(iter: anytype, predicate: *const fn (Item(@TypeOf(iter))) bool) SkipWhileIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .predicate = predicate };
}

test "skipWhile" {
    var base_iter = range(u32, 0, 10);
    const predicate = struct {
        fn predicate(x: u32) bool {
            return x < 5;
        }
    }.predicate;
    var iter = skipWhile(base_iter, predicate);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 5), iter.next());
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, 7), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, 9), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
