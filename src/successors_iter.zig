const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An new iterator where each successive item is computed based on the preceding one.
///
/// See `successors` for more info.
pub fn SuccessorsIter(comptime T: type) type {
    return struct {
        const Self = @This();

        current: ?T,
        func: *const fn (T) ?T,

        pub fn next(self: *Self) ?T {
            const current = self.current orelse return null;
            self.current = self.func(current);
            return current;
        }
    };
}

/// Creates a new iterator where each successive item is computed based on the
/// preceding one.
///
/// The iterator starts with the given first item (if any) and calls the given
/// function to compute each item’s successor.
pub fn successors(
    init: anytype,
    func: *const fn (@TypeOf(init)) ?@TypeOf(init),
) SuccessorsIter(@TypeOf(init)) {
    return .{ .current = init, .func = func };
}

test "successors" {
    const func = struct {
        fn func(x: u32) ?u32 {
            if (x >= 5) return null;
            return x + 1;
        }
    }.func;
    var iter = successors(@as(u32, 0), func);
    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, 5), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
