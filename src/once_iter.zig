const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;

/// An iterator that yields an element exactly once.
///
/// See `empty` for more info.
pub fn OnceIter(comptime T: type) type {
    return struct {
        const Self = @This();

        value: ?T,

        pub fn next(self: *Self) ?T {
            const value = self.value orelse return null;
            self.value = null;
            return value;
        }
    };
}

/// Creates an iterator that yields an element exactly once.
///
/// This is commonly used to adapt a single value into a `chain()` of other
/// kinds of iteration. Maybe you have an iterator that covers almost
/// everything, but you need an extra special case. Maybe you have a function
/// which works on iterators, but you only need to process one value.
pub fn once(value: anytype) OnceIter(@TypeOf(value)) {
    return .{ .value = value };
}

test "Once" {
    var iter = once(@as(u32, 42));
    try std.testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 42), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
