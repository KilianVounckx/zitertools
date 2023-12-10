const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const RangeIter = itertools.RangeIter;

/// An iterator that flattens one level of nesting in an iterator of things that
/// can be turned into iterators.
///
/// see `flatten` for more info.
pub fn FlattenIter(comptime BaseIters: type) type {
    return struct {
        const Self = @This();

        base_iters: BaseIters,
        current_iter: ?Item(BaseIters),

        pub const Next = if (IterError(BaseIters)) |ESB|
            if (IterError(Item(BaseIters))) |ESI|
                (ESB || ESI)!?Item(Item(BaseIters))
            else
                ESB!?Item(Item(BaseIters))
        else if (IterError(Item(BaseIters))) |ESI|
            ESI!?Item(Item(BaseIters))
        else
            ?Item(Item(BaseIters));

        pub fn next(self: *Self) Next {
            const base_has_error = comptime IterError(BaseIters) != null;
            const item_has_error = comptime IterError(Item(BaseIters)) != null;

            const iter = &(self.current_iter orelse return null);
            const maybe_item = if (item_has_error)
                try iter.next()
            else
                iter.next();
            if (maybe_item) |item|
                return item;

            self.current_iter = if (base_has_error)
                try self.base_iters.next()
            else
                self.base_iters.next();
            return @call(.always_tail, Self.next, .{self});
        }
    };
}

/// Creates an iterator that flattens nested structure.
///
/// This is useful when you have an iterator of iterators or an iterator of
/// things that can be turned into iterators and you want to remove one level of
/// indirection.
pub fn flatten(iter: anytype) FlattenIter(@TypeOf(iter)) {
    var iters = iter;
    const current = if (IterError(@TypeOf(iter)) != null)
        try iters.next()
    else
        iters.next();
    return .{ .base_iters = iters, .current_iter = current };
}

test "Flatten" {
    const func = struct {
        fn func(x: u32) RangeIter(u32) {
            return itertools.range(u32, 0, x);
        }
    }.func;

    var iters = itertools.map(itertools.range(u32, 0, 5), func);
    var iter = flatten(iters);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}
