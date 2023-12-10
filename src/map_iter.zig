const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Iter type for mapping another iterator with a function
///
/// See `map` for more info.
pub fn MapIter(comptime BaseIter: type, comptime func: anytype) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,

        pub const Dest = @typeInfo(@TypeOf(func)).Fn.return_type.?;
        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                try self.base_iter.next()
            else
                self.base_iter.next();

            return if (maybe_item) |item|
                func(item)
            else
                null;
        }
    };
}

/// Iter type for mapping another iterator with a function and context
///
/// See `mapContext` for more info.
pub fn MapContextIter(
    comptime BaseIter: type,
    comptime func: anytype,
) type {
    const Fn = @typeInfo(@TypeOf(func)).Fn;
    const Context = Fn.params[0].type.?;
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        context: Context,

        pub const Dest = Fn.return_type.?;
        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                try self.base_iter.next()
            else
                self.base_iter.next();

            return if (maybe_item) |item|
                func(self.context, item)
            else
                null;
        }
    };
}

/// Returns a new iterator which maps items in iter using func as a function.
///
/// iter must be an iterator, meaning it has to be a type containing a next method which returns
/// an optional. func must be a unary function for which it's first argument type is the iterator's
/// item type.
pub fn map(
    iter: anytype,
    comptime func: anytype,
) MapIter(
    @TypeOf(iter),
    validateMapFn(Item(@TypeOf(iter)), func),
) {
    return .{ .base_iter = iter };
}

fn validateMapFn(
    comptime Source: type,
    comptime func: anytype,
) fn (Source) @typeInfo(@TypeOf(func)).Fn.return_type.? {
    return func;
}

/// Returns a new iterator which maps items in iter using func as a function and context as the
/// first argument to func.
///
/// Context is useful for when you want to pass in a function that behaves like a closure.
pub fn mapContext(
    iter: anytype,
    context: anytype,
    comptime func: anytype,
) MapContextIter(
    @TypeOf(iter),
    validateMapContextFn(Item(@TypeOf(iter)), @TypeOf(context), func),
) {
    return .{ .base_iter = iter, .context = context };
}

fn validateMapContextFn(
    comptime Source: type,
    comptime Context: type,
    comptime func: anytype,
) fn (Context, Source) @typeInfo(@TypeOf(func)).Fn.return_type.? {
    return func;
}

test "MapIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    const functions = struct {
        pub fn double(x: u32) u64 {
            return 2 * x;
        }

        pub fn addOne(x: u64) u65 {
            return x + 1;
        }
    };

    var iter = map(map(slice_iter, functions.double), functions.addOne);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
}

test "MapIter error" {
    var test_iter = TestErrorIter.init(3);

    const double = struct {
        pub fn double(x: usize) u64 {
            return 2 * x;
        }
    }.double;

    var iter = map(test_iter, double);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 0), try iter.next());
    try testing.expectEqual(@as(?u64, 2), try iter.next());
    try testing.expectEqual(@as(?u64, 4), try iter.next());
    try testing.expectError(error.TestErrorIterError, iter.next());
}

test "MapIter value closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    const bias: u32 = 1;
    const Closure = struct {
        enclosed: u32,
        pub fn apply(self: @This(), x: u32) u65 {
            return x * 2 + self.enclosed;
        }
    };

    var iter = mapContext(slice_iter, Closure{ .enclosed = bias }, Closure.apply);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
}

test "MapIter reference closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    var acc: u32 = 0;
    const Closure = struct {
        enclosed: *u32,
        pub fn apply(self: *@This(), x: u32) u65 {
            if (x % 2 == 0) {
                self.enclosed.* += x;
            }
            return x * 2 + 1;
        }
    };

    var closure = Closure{ .enclosed = &acc };
    var iter = mapContext(slice_iter, &closure, Closure.apply);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(u32, 6), acc);
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
