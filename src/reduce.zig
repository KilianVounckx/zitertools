const std = @import("std");
const testing = std.testing;
const Child = std.meta.Child;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Returns the return type to be used in `reduce`
pub fn Reduce(comptime Iter: type, comptime T: type) type {
    return if (IterError(Iter)) |ES|
        ES!T
    else
        T;
}

/// Applies a binary operator between all items in iter with an initial element.
///
/// Also know as fold in functional languages.
pub fn reduce(
    iter: anytype,
    comptime T: type,
    func: *const fn (T, Item(Child(@TypeOf(iter)))) T,
    init: T,
) Reduce(Child(@TypeOf(iter)), T) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var res = init;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        res = func(res, item);
    }
    return res;
}

test "reduce" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = sliceIter(u32, slice);

    const add = struct {
        fn add(x: u64, y: u32) u64 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(u64, 10), reduce(&iter, u64, add, 0));
}

test "reduce error" {
    var iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: u64, y: usize) u64 {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, reduce(&iter, u64, add, 0));
}

/// Returns the return type to be used in `reduce1`
pub fn Reduce1(comptime Iter: type) type {
    return if (IterError(Iter)) |ES|
        (error{EmptyIterator} || ES)!Item(Iter)
    else
        error{EmptyIterator}!Item(Iter);
}

/// Applies a binary operator between all items in iter with no initial element.
///
/// If the iterator is empty `error.EmptyIterator` is returned.
///
/// Also know as fold1 in functional languages.
pub fn reduce1(
    iter: anytype,
    func: *const fn (
        Item(Child(@TypeOf(iter))),
        Item(Child(@TypeOf(iter))),
    ) Item(Child(@TypeOf(iter))),
) Reduce1(Child(@TypeOf(iter))) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    const maybe_init = if (has_error) try iter.next() else iter.next();
    const init = maybe_init orelse return error.EmptyIterator;
    return reduce(iter, Item(Child(@TypeOf(iter))), func, init);
}

test "reduce1" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = sliceIter(u32, slice);

    const add = struct {
        fn add(x: u32, y: u32) u32 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(u32, 10), try reduce1(&iter, add));
    try testing.expectError(error.EmptyIterator, reduce1(&iter, add));
}

test "reduce1 error" {
    var iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: usize, y: usize) usize {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, reduce1(&iter, add));
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
