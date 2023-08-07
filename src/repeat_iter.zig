const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that repeats an element endlessly.
///
/// See `repeat` for more info.
pub fn RepeatIter(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn next(self: *Self) ?T {
            return self.value;
        }
    };
}

/// Creates a new iterator that endlessly repeats a single element.
///
/// The `repeat()` function repeats a single value over and over again.
///
/// Infinite iterators like repeat() are often used with adapters like
/// `take`, in order to make them finite.
pub fn repeat(value: anytype) RepeatIter(@TypeOf(value)) {
    return .{ .value = value };
}

test "Cycle" {
    var iter = repeat(@as(u32, 42));
    try std.testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, 42), iter.next());
}
