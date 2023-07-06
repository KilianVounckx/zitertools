const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;

/// Iter type for iterating over slice values
pub fn SliceIter(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []const T,
        index: usize = 0,

        /// Creates an iterator iterating over values in slice
        pub fn init(slice: []const T) Self {
            return .{ .slice = slice };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.slice.len)
                return null;
            self.index += 1;
            return self.slice[self.index - 1];
        }
    };
}

test "SliceIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
