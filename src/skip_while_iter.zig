const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const IterError = itertools.IterError;
const Item = itertools.Item;
const range = itertools.range;
const findContext = itertools.findContext;

/// An iterator that rejects elements while predicate returns true.
///
/// See `skipWhile` for more info.
pub fn SkipWhileIter(comptime BaseIter: type, comptime predicate: fn (*const Item(BaseIter)) bool) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        flag: bool = false,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const Check = struct {
                flag: *bool,
                fn call(self_Check: @This(), item: *const Item(BaseIter)) bool {
                    if (self_Check.flag.* or !predicate(item)) {
                        self_Check.flag.* = true;
                        return true;
                    } else {
                        return false;
                    }
                }
            };
            return findContext(&self.base_iter, Check{ .flag = &self.flag }, Check.call);
        }
    };
}

/// An iterator that rejects elements while predicate returns true, given the context.
///
/// See `skipWhileContext` for more info.
pub fn SkipWhileContextIter(
    comptime BaseIter: type,
    comptime Context: type,
    comptime predicate: fn (Context, *const Item(BaseIter)) bool,
) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        context: Context,
        flag: bool = false,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const Check = struct {
                context: Context,
                flag: *bool,
                fn call(self_Check: @This(), item: *const Item(BaseIter)) bool {
                    if (self_Check.flag.* or !predicate(self_Check.context, item)) {
                        self_Check.flag.* = true;
                        return true;
                    } else {
                        return false;
                    }
                }
            };
            return findContext(
                &self.base_iter,
                Check{ .context = self.context, .flag = &self.flag },
                Check.call,
            );
        }
    };
}

// Creates an iterator that skips elements based on a predicate.
//
// `skipWhile()` takes a function as an argument. It will call this function
/// on each element of the iterator, and ignore elements until it returns
/// false.
//
// After false is returned, `skipWhile()`’s job is over, and the rest of the
/// elements are yielded.
pub fn skipWhile(
    iter: anytype,
    comptime predicate: fn (*const Item(@TypeOf(iter))) bool,
) SkipWhileIter(@TypeOf(iter), predicate) {
    return .{ .base_iter = iter };
}

/// Creates an iterator that skips elements based on a predicate, given the context.
///
/// `skipWhileContext()` takes a function as an argument. It will call this function
/// on each element of the iterator, and ignore elements until it returns
/// false.
///
/// After false is returned, `skipWhileContext()`’s job is over, and the rest of the
/// elements are yielded.
pub fn skipWhileContext(
    iter: anytype,
    context: anytype,
    comptime predicate: fn (@TypeOf(context), *const Item(@TypeOf(iter))) bool,
) SkipWhileContextIter(@TypeOf(iter), @TypeOf(context), predicate) {
    return .{ .base_iter = iter, .context = context };
}

test "skipWhile" {
    var base_iter = range(u32, 0, 10);
    const predicate = struct {
        fn predicate(x: *const u32) bool {
            return x.* < 5;
        }
    }.predicate;
    var iter = skipWhile(base_iter, predicate);
    try testing.expectEqual(Item(@TypeOf(base_iter)), Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 5), iter.next());
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, 7), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, 9), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "skipWhile error" {
    var base_iter = TestErrorIter{ .until_err = 3 };
    const predicate = struct {
        fn predicate(x: *const usize) bool {
            return x.* < 5;
        }
    }.predicate;
    var iter = skipWhile(base_iter, predicate);
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
