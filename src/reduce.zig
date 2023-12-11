const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Returns the return type to be used in `reduce`
pub fn Reduce(comptime Iter: type) type {
    return if (IterError(Iter)) |ES| ES!?Item(Iter) else ?Item(Iter);
}

/// Applies a binary operator between all items in iter with no initial element.
pub fn reduce(
    iter: anytype,
    comptime func: fn (
        Item(@TypeOf(iter)),
        Item(@TypeOf(iter)),
    ) Item(@TypeOf(iter)),
) Reduce(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    var mut_iter = iter;
    const maybe_init = if (has_error) try mut_iter.next() else mut_iter.next();
    return if (has_error) try itertools.fold(
        mut_iter,
        maybe_init orelse return null,
        func,
    ) else itertools.fold(
        mut_iter,
        maybe_init orelse return null,
        func,
    );
}

/// Applies a binary operator between all items in iter with an initial element and a context.
///
/// The context is passed as the first argument to the function. Context is useful for
/// when you want to pass in a function that behaves like a closure.
pub fn reduceContext(
    iter: anytype,
    context: anytype,
    comptime func: fn (
        @TypeOf(context),
        Item(@TypeOf(iter)),
        Item(@TypeOf(iter)),
    ) Item(@TypeOf(iter)),
) Reduce(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    var mut_iter = iter;
    const maybe_init = if (has_error) try mut_iter.next() else mut_iter.next();
    return itertools.foldContext(
        mut_iter,
        context,
        maybe_init orelse return null,
        func,
    );
}

test "reduce" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    const iter = sliceIter(u32, slice);

    const add = struct {
        fn add(x: u32, y: u32) u32 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(?u32, 10), reduce(iter, add));
}

test "reduce context" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    const iter = sliceIter(u32, slice);

    const add = struct {
        fn add(context: u32, x: u32, y: u32) u32 {
            return x + y + context;
        }
    }.add;

    const context: u32 = 5;
    try testing.expectEqual(@as(?u32, 25), reduceContext(iter, context, add));
}

test "reduce empty" {
    const slice: []const u32 = &.{};
    const iter = sliceIter(u32, slice);

    const add = struct {
        fn add(x: u32, y: u32) u32 {
            return x + y;
        }
    }.add;

    try testing.expect(reduce(iter, add) == null);
}

test "reduce error" {
    const iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: usize, y: usize) usize {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, reduce(iter, add));
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
