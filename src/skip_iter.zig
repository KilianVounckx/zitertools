const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that skips over n elements of iter.
///
/// See `skip` for more info.
pub fn SkipIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        to_skip: usize,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = IterError(BaseIter) != null;
            if (self.to_skip > 0) {
                for (0..self.to_skip) |_| {
                    if (has_error) {
                        _ = try self.base_iter.next();
                    } else {
                        _ = self.base_iter.next();
                    }
                }
                self.to_skip = 0;
            }
            return if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
        }
    };
}

/// Creates an iterator that skips the first n elements.
///
/// skip(iter, n) skips elements until n elements are skipped or the end of the
/// iterator is reached (whichever happens first). After that, all the
/// remaining elements are yielded. In particular, if the original iterator is
/// too short, then the returned iterator is empty.
pub fn skip(iter: anytype, to_skip: usize) SkipIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .to_skip = to_skip };
}

test "skip" {
    var base_iter = range(u32, 5, 10);
    var iter = skip(base_iter, 2);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 7), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, 9), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
