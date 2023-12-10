const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Iter type for filtering another iterator with a predicate
///
/// See `filter` for more info.
pub fn FilterIter(comptime BaseIter: type, comptime predicate: fn (*const Item(BaseIter)) bool) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (predicate(&item))
                return item;
            return @call(.always_tail, Self.next, .{self});
        }
    };
}

pub fn FilterContextIter(
    comptime BaseIter: type,
    comptime Context: type,
    comptime predicate: fn (Context, *const Item(BaseIter)) bool,
) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        context: Context,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (predicate(self.context, &item))
                return item;
            return @call(.always_tail, Self.next, .{self});
        }
    };
}

/// Returns a new iterator which filters items in iter with predicate
///
/// iter must be an iterator, meaning it has to be a type containing a next method which returns
/// an optional.
pub fn filter(
    iter: anytype,
    comptime predicate: fn (*const Item(@TypeOf(iter))) bool,
) FilterIter(@TypeOf(iter), predicate) {
    return .{ .base_iter = iter };
}

pub fn filterContext(
    iter: anytype,
    context: anytype,
    comptime predicate: fn (@TypeOf(context), *const Item(@TypeOf(iter))) bool,
) FilterContextIter(@TypeOf(iter), @TypeOf(context), predicate) {
    return .{ .base_iter = iter, .context = context };
}

test "FilterIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = sliceIter(u32, slice);

    const predicates = struct {
        pub fn even(x: *const u32) bool {
            return x.* % 2 == 0;
        }

        pub fn big(x: *const u32) bool {
            return x.* > 4;
        }
    };

    var iter = filter(filter(slice_iter, predicates.even), predicates.big);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "FilterContextIter simple" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = sliceIter(u32, slice);

    const predicates = struct {
        pub fn dividible(divisor: u32, x: *const u32) bool {
            return x.* % divisor == 0;
        }
    };

    var iter = filterContext(slice_iter, @as(u32, 3), predicates.dividible);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "FilterContextIter closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = sliceIter(u32, slice);

    const Closure = struct {
        divisor: u32,
        pub fn dividible(self: @This(), x: *const u32) bool {
            return x.* % self.divisor == 0;
        }
    };
    var iter = filterContext(slice_iter, Closure{ .divisor = 3 }, Closure.dividible);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "FilterIter error" {
    var test_iter = TestErrorIter.init(5);

    const even = struct {
        pub fn even(x: *const usize) bool {
            return x.* % 2 == 0;
        }
    }.even;

    var iter = filter(test_iter, even);

    try testing.expectEqual(usize, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?usize, 0), try iter.next());
    try testing.expectEqual(@as(?usize, 2), try iter.next());
    try testing.expectEqual(@as(?usize, 4), try iter.next());
    try testing.expectError(error.TestErrorIterError, iter.next());
}

const TestErrorIter = struct {
    const Self = @This();

    counter: usize = 0,
    until_err: usize,

    pub fn init(until_err: usize) Self {
        return .{ .until_err = until_err };
    }

    pub fn next(self: *Self) !?usize {
        if (self.counter >= self.until_err) return error.TestErrorIterError;
        self.counter += 1;
        return self.counter - 1;
    }
};
