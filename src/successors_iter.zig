const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An new iterator where each successive item is computed based on the preceding one.
///
/// See `successors` for more info.
pub fn SuccessorsIter(comptime T: type, comptime succ: fn (*const T) ?T) type {
    return struct {
        const Self = @This();

        next_item: ?T,

        pub fn next(self: *Self) ?T {
            const item: T = self.next_item orelse return null;
            self.next_item = succ(&item);
            return item;
        }
    };
}

pub fn SuccessorsContextIter(comptime T: type, comptime Context: type, comptime succ: fn (Context, *const T) ?T) type {
    return struct {
        const Self = @This();

        next_item: ?T,
        context: Context,

        pub fn next(self: *Self) ?T {
            const item: T = self.next_item orelse return null;
            self.next_item = succ(self.context, &item);
            return item;
        }
    };
}

/// Creates a new iterator where each successive item is computed based on the
/// preceding one.
///
/// The iterator starts with the given first item, if any, and calls the given
/// function to compute each item’s successor.
pub fn successors(
    comptime T: type,
    first: ?T,
    comptime succ: fn (*const T) ?T,
) SuccessorsIter(T, succ) {
    return .{ .next_item = first };
}

/// Creates a new iterator where each successive item is computed based on the
/// preceding one, given the context.
///
/// The iterator starts with the given first item, if any, and calls the given
/// function to compute each item’s successor.
pub fn successorsContext(
    comptime T: type,
    first: ?T,
    context: anytype,
    comptime func: fn (@TypeOf(context), *const T) ?T,
) SuccessorsContextIter(T, @TypeOf(context), func) {
    return .{ .next_item = first, .context = context };
}

test "successors" {
    const func = struct {
        fn func(x: *const u32) ?u32 {
            if (x.* >= 5) return null;
            return x.* + 1;
        }
    }.func;
    var iter = successors(u32, 0, func);
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
        fn fib(context: *u32, x: *const u32) ?u32 {
            defer context.* += x.*;
            return context.*;
        }
    }.fib;
    var context: u32 = 1;
    var iter = successorsContext(u32, 0, &context, func);
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
