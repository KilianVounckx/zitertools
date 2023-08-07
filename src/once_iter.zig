const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;

/// An iterator that yields nothing.
/// An iterator that yields an element exactly once.
///
/// See `once` for more info.
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
