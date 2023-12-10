const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An new iterator where each successive item is computed based on the preceding one.
///
/// See `successors` for more info.
pub fn SuccessorsIter(comptime T: type, comptime func: fn (T) ?T) type {
    return struct {
        const Self = @This();

        current: ?T,

        pub fn next(self: *Self) ?T {
            const current = self.current orelse return null;
            self.current = func(current);
            return current;
        }
    };
}

pub fn SuccessorsContextIter(comptime T: type, comptime Context: type, comptime func: fn (Context, T) ?T) type {
    return struct {
        const Self = @This();

        current: ?T,
        context: Context,

        pub fn next(self: *Self) ?T {
            const current = self.current orelse return null;
            self.current = func(self.context, current);
            return current;
        }
    };
}

/// Creates a new iterator where each successive item is computed based on the
/// preceding one.
///
/// The iterator starts with the given first item and calls the given
/// function to compute each item’s successor.
pub fn successors(
    init: anytype,
    comptime func: fn (@TypeOf(init)) ?@TypeOf(init),
) SuccessorsIter(@TypeOf(init), func) {
    return .{ .current = init };
}

/// Creates a new iterator where each successive item is computed based on the
/// preceding one, given the context.
///
/// The iterator starts with the given first item and calls the given
/// function to compute each item’s successor.
pub fn successorsContext(
    init: anytype,
    context: anytype,
    comptime func: fn (@TypeOf(context), @TypeOf(init)) ?@TypeOf(init),
) SuccessorsContextIter(@TypeOf(init), @TypeOf(context), func) {
    return .{ .current = init, .context = context };
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

test "successorsContext fibbonacci" {
    const func = struct {
        fn fib(context: *u32, x: u32) ?u32 {
            defer context.* += x;
            return context.*;
        }
    }.fib;
    var context: u32 = 1;
    var iter = successorsContext(@as(u32, 0), &context, func);
    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 5), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, 13), iter.next());
    try testing.expectEqual(@as(?u32, 21), iter.next());
}
