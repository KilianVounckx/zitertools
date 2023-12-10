const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// An iterator that uses f to both filter and map elements from iter.
///
/// See `map` for more info.
pub fn FilterMapIter(comptime BaseIter: type, comptime func: anytype) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,

        pub const Dest = @typeInfo(@typeInfo(@TypeOf(func)).Fn.return_type.?).Optional.child;
        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();

            const item = maybe_item orelse return null;
            return if (func(item)) |transformed|
                transformed
            else
                @call(.always_tail, Self.next, .{self}); // no need to `try` because the error union, if any, stays the same
        }
    };
}

pub fn FilterMapContextIter(
    comptime BaseIter: type,
    comptime Context: type,
    comptime func: anytype,
) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        context: Context,

        pub const Dest = @typeInfo(@typeInfo(@TypeOf(func)).Fn.return_type.?).Optional.child;
        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();

            const item = maybe_item orelse return null;
            return if (func(self.context, item)) |transformed|
                transformed
            else
                @call(.always_tail, Self.next, .{self}); // no need to `try` because the error union, if any, stays the same
        }
    };
}

/// Creates an iterator that both filters and maps.
///
/// The returned iterator yields only the values for which the supplied function does not return null.
///
/// filterMap can be used to make chains of filter and map more concise.
pub fn filterMap(
    iter: anytype,
    comptime func: anytype,
) FilterMapIter(@TypeOf(iter), validateFilterMapFn(Item(@TypeOf(iter)), func)) {
    return .{ .base_iter = iter };
}

fn validateFilterMapFn(
    comptime Source: type,
    comptime func: anytype,
) fn (Source) ?@typeInfo(@typeInfo(@TypeOf(func)).Fn.return_type.?).Optional.child {
    return func;
}

pub fn filterMapContext(
    iter: anytype,
    context: anytype,
    comptime func: anytype,
) FilterMapContextIter(
    @TypeOf(iter),
    @TypeOf(context),
    validateFilterMapContextFn(Item(@TypeOf(iter)), @TypeOf(context), func),
) {
    return .{ .base_iter = iter, .context = context };
}

fn validateFilterMapContextFn(
    comptime Source: type,
    comptime Context: type,
    comptime func: anytype,
) fn (Context, Source) ?@typeInfo(@typeInfo(@TypeOf(func)).Fn.return_type.?).Optional.child {
    return func;
}

test "FilterMapIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = sliceIter(u32, slice);

    const func = struct {
        pub fn func(x: u32) ?u64 {
            return if (x % 2 == 0)
                x / 2
            else
                null;
        }
    }.func;

    var iter = filterMap(slice_iter, func);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 1), iter.next());
    try testing.expectEqual(@as(?u64, 2), iter.next());
    try testing.expectEqual(@as(?u64, 3), iter.next());
    try testing.expectEqual(@as(?u64, 4), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
}

test "FilterMapContextIter simple" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = sliceIter(u32, slice);

    const func = struct {
        pub fn func(context: u32, x: u32) ?u64 {
            return if (x % context == 0)
                x / context
            else
                null;
        }
    }.func;

    var iter = filterMapContext(slice_iter, @as(u32, 2), func);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 1), iter.next());
    try testing.expectEqual(@as(?u64, 2), iter.next());
    try testing.expectEqual(@as(?u64, 3), iter.next());
    try testing.expectEqual(@as(?u64, 4), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
}

test "FilterMapContextIter closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var slice_iter = sliceIter(u32, slice);

    const Closure = struct {
        divider: u32,
        pub fn func(self: @This(), x: u32) ?u64 {
            return if (x % self.divider == 0)
                x / self.divider
            else
                null;
        }
    };

    var iter = filterMapContext(slice_iter, Closure{ .divider = 3 }, Closure.func);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 1), iter.next());
    try testing.expectEqual(@as(?u64, 2), iter.next());
    try testing.expectEqual(@as(?u64, 3), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
}

test "MapIter error" {
    var test_iter = TestErrorIter.init(3);

    const func = struct {
        pub fn func(x: usize) ?u64 {
            return if (x % 2 == 0)
                x / 2
            else
                null;
        }
    }.func;

    var iter = filterMap(test_iter, func);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 0), try iter.next());
    try testing.expectEqual(@as(?u64, 1), try iter.next());
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
