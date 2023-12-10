const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;

/// An iterator that only accepts elements while predicate returns true.
///
/// See `takeWhile` for more info.
pub fn TakeWhileIter(
    comptime BaseIter: type,
    comptime predicate: fn (Item(BaseIter)) bool,
) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        flag: bool = false,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            if (self.flag) return null;

            const has_error = IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (predicate(item)) return item;
            self.flag = true;
            return null;
        }
    };
}

/// An iterator that only accepts elements while predicate returns true, given the context.
///
/// See `takeWhileContext` for more info.
pub fn TakeWhileContextIter(
    comptime BaseIter: type,
    comptime Context: type,
    comptime predicate: fn (Context, Item(BaseIter)) bool,
) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        context: Context,
        flag: bool = false,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            if (self.flag) return null;

            const has_error = IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (predicate(self.context, item)) return item;
            self.flag = true;
            return null;
        }
    };
}

/// Creates an iterator that yields elements based on a predicate.
///
/// `takeWhile()` takes a function as an argument. It will call this function
/// on each element of the iterator, and yield elements while it returns true.
///
/// After false is returned, `takeWhile()`'s job is over, and the rest of the
/// elements are ignored.
pub fn takeWhile(
    iter: anytype,
    comptime predicate: fn (Item(@TypeOf(iter))) bool,
) TakeWhileIter(@TypeOf(iter), predicate) {
    return .{ .base_iter = iter };
}

/// Creates an iterator that yields elements based on a predicate, given the context.
///
/// `takeWhileContext()` takes a function as an argument. It will call this function
/// on each element of the iterator, and yield elements while it returns true.
///
/// After false is returned, `takeWhileContext()`'s job is over, and the rest of the
/// elements are ignored.
pub fn takeWhileContext(
    iter: anytype,
    context: anytype,
    comptime predicate: fn (@TypeOf(context), Item(@TypeOf(iter))) bool,
) TakeWhileContextIter(@TypeOf(iter), @TypeOf(context), predicate) {
    return .{ .base_iter = iter, .context = context };
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

test "takeWhileContext" {
    var base_iter = range(u32, 0, 10);
    const predicate = struct {
        fn predicate(context: u32, x: u32) bool {
            return x < context;
        }
    }.predicate;
    var iter = takeWhileContext(base_iter, @as(u32, 5), predicate);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
