const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that only accepts elements while predicate returns true.
///
/// See `takeWhile` for more info.
pub fn TakeWhileIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        predicate: ?*const fn (Item(BaseIter)) bool,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const predicate = self.predicate orelse return null;

            const has_error = IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (predicate(item)) return item;
            self.predicate = null;
            return null;
        }
    };
}

/// Creates an iterator that yields elements based on a predicate.
///
/// `take_while()` takes a function as an argument. It will call this function
/// on each element of the iterator, and yield elements while it returns true.
///
/// After false is returned, `take_while()`’s job is over, and the rest of the
/// elements are ignored.
pub fn takeWhile(iter: anytype, predicate: *const fn (Item(@TypeOf(iter))) bool) TakeWhileIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .predicate = predicate };
}

test "takeWhile" {
    var base_iter = range(u32, 0, 10);
    const predicate = struct {
        fn predicate(x: u32) bool {
            return x < 5;
        }
    }.predicate;
    var iter = takeWhile(base_iter, predicate);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
