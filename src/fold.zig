const std = @import("std");
const testing = std.testing;
const Child = std.meta.Child;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Returns the return type to be used in `reduce`
pub fn Fold(comptime Iter: type, comptime T: type) type {
    return if (IterError(Iter)) |ES|
        ES!?T
    else
        ?T;
}

/// Applies a binary operator between all items in iter with an initial element.
pub fn fold(
    iter: anytype,
    comptime T: type,
    init: T,
    comptime func: fn (T, Item(Child(@TypeOf(iter)))) T,
) Fold(Child(@TypeOf(iter)), T) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var res = init;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        res = func(res, item);
    }
    return res;
}

pub fn foldContext(
    iter: anytype,
    context: anytype,
    comptime T: type,
    init: T,
    comptime func: fn (@TypeOf(context), T, Item(Child(@TypeOf(iter)))) T,
) Fold(Child(@TypeOf(iter)), T) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var res = init;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        res = func(context, res, item);
    }
    return res;
}

test "fold" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = sliceIter(u32, slice);

    const add = struct {
        fn add(x: u64, y: u32) u64 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(?u64, 10), fold(&iter, u64, 0, add));
}

test "fold error" {
    var iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: u64, y: usize) u64 {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, fold(&iter, u64, 0, add));
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
