const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// Iter type for mapping another iterator with a function
///
/// See `map` for more info.
pub fn MapIter(comptime BaseIter: type, comptime Dest: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        func: *const fn (Item(BaseIter)) Dest,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            return if (maybe_item) |item|
                self.func(item)
            else
                null;
        }
    };
}

/// Returns the destination type for a given base iterator and function type
pub fn MapDestType(comptime BaseIter: type, comptime Func: type) type {
    const Source = Item(BaseIter);

    const func = switch (@typeInfo(Func)) {
        .Fn => |func| func,
        else => @compileError("map func must be a function"),
    };

    if (func.params.len != 1)
        @compileError("map func must be a unary function");

    if (func.params[0].type.? != Source)
        @compileError("map func's argument must be iter's item type");

    return func.return_type.?;
}

/// Returns a new iterator which maps items in iter using func as a function.
///
/// iter must be an iterator, meaning it has to be a type containing a next method which returns
/// an optional. func must be a unary function for which it's first argument type is the iterator's
/// item type.
pub fn map(
    iter: anytype,
    func: anytype,
) MapIter(@TypeOf(iter), MapDestType(@TypeOf(iter), @TypeOf(func))) {
    return .{ .base_iter = iter, .func = func };
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
