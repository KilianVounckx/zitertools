const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

/// An iterator that uses f to both filter and map elements from iter.
///
/// See `map` for more info.
pub fn FilterMapIter(comptime BaseIter: type, comptime Dest: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        func: *const fn (Item(BaseIter)) ?Dest,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();

            const item = maybe_item orelse return null;
            return if (self.func(item)) |transformed|
                transformed
            else if (has_error)
                try self.next()
            else
                self.next();
        }
    };
}

/// Returns the destination type for a given base iterator and function type
pub fn FilterMapDestType(comptime BaseIter: type, comptime Func: type) type {
    const Source = Item(BaseIter);

    const func = switch (@typeInfo(Func)) {
        .Fn => |func| func,
        else => @compileError("filterMap func must be a function"),
    };

    if (func.params.len != 1)
        @compileError("filterMap func must be a unary function");

    if (func.params[0].type.? != Source)
        @compileError("filterMap func's argument must be iter's item type");

    return switch (@typeInfo(func.return_type.?)) {
        .Optional => |optional| optional.child,
        else => @compileError("filterMap func's return type must be an optional"),
    };
}

/// Creates an iterator that both filters and maps.
///
/// The returned iterator yields only the values for which the supplied function does not return null.
///
/// filterMap can be used to make chains of filter and map more concise.
pub fn filterMap(
    iter: anytype,
    func: anytype,
) FilterMapIter(@TypeOf(iter), FilterMapDestType(@TypeOf(iter), @TypeOf(func))) {
    return .{ .base_iter = iter, .func = func };
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
