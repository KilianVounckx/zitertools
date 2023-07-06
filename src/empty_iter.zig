const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;

/// An iterator that yields nothing.
pub fn EmptyIter(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn next(self: Self) ?T {
            _ = self;
            return null;
        }
    };
}

pub fn empty(comptime T: type) EmptyIter(T) {
    return .{};
}

test "Empty" {
    var iter = empty(u32);
    try std.testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
