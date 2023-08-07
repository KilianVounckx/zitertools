const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;
const range = itertools.range;

/// An iterator that iterates two other iterators simultaneously.
///
/// See `zip` for more info.
pub fn ZipIter(comptime A: type, comptime B: type) type {
    return struct {
        const Self = @This();

        a: A,
        b: B,

        pub const Item = struct { itertools.Item(A), itertools.Item(B) };

        pub const Next = if (IterError(A)) |ESA|
            if (IterError(B)) |ESB|
                (ESA || ESB)!?Self.Item
            else
                ESA!?Self.Item
        else if (IterError(B)) |ESB|
            ESB!?Self.Item
        else
            ?Self.Item;

        pub fn next(self: *Self) Next {
            const a_has_error = comptime IterError(A) != null;
            const b_has_error = comptime IterError(B) != null;
            const maybe_a = if (a_has_error)
                try self.a.next()
            else
                self.a.next();
            const a = maybe_a orelse return null;
            const maybe_b = if (b_has_error)
                try self.b.next()
            else
                self.b.next();
            const b = maybe_b orelse return null;
            return .{ a, b };
        }
    };
}

/// ‘Zips up’ two iterators into a single iterator of pairs.
///
/// `zip()` returns a new iterator that will iterate over two other iterators,
/// returning a tuple where the first element comes from the first iterator,
/// and the second element comes from the second iterator.
///
/// In other words, it zips two iterators together, into a single one.
///
/// If either iterator returns null, next from the zipped iterator will return
/// null. If the zipped iterator has no more elements to return then each
/// further attempt to advance it will first try to advance the first iterator
/// at most one time and if it still yielded an item try to advance the second
/// iterator at most one time.
pub fn zip(iter1: anytype, iter2: anytype) ZipIter(@TypeOf(iter1), @TypeOf(iter2)) {
    return .{ .a = iter1, .b = iter2 };
}

test "zip" {
    var iter1 = sliceIter(u32, &.{ 1, 2, 3 });
    var iter2 = range(u64, 5, 8);
    var iter = zip(iter1, iter2);
    try testing.expectEqual(@TypeOf(iter).Item, Item(@TypeOf(iter)));
    const v1 = iter.next().?;
    try testing.expectEqual(@as(u32, 1), v1.@"0");
    try testing.expectEqual(@as(u64, 5), v1.@"1");
    const v2 = iter.next().?;
    try testing.expectEqual(@as(u32, 2), v2.@"0");
    try testing.expectEqual(@as(u64, 6), v2.@"1");
    const v3 = iter.next().?;
    try testing.expectEqual(@as(u32, 3), v3.@"0");
    try testing.expectEqual(@as(u64, 7), v3.@"1");
    try testing.expectEqual(@as(?Item(@TypeOf(iter)), null), iter.next());
}
