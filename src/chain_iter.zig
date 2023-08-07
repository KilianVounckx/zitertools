const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;
const range = itertools.range;

/// An iterator that links two iterators together, in a chain.
///
/// See `chain` for more info.
pub fn ChainIter(comptime A: type, comptime B: type) type {
    if (Item(A) != Item(B))
        @compileError("Both chain iterators must yield the same type");
    const Dest = Item(A);

    return struct {
        const Self = @This();

        a: A,
        b: B,
        a_done: bool,

        pub const Next = if (IterError(A)) |ESA|
            if (IterError(B)) |ESB|
                (ESA || ESB)!?Dest
            else
                ESA!?Dest
        else if (IterError(B)) |ESB|
            ESB!?Dest
        else
            ?Dest;

        pub fn next(self: *Self) Next {
            const a_has_error = comptime IterError(A) != null;
            const b_has_error = comptime IterError(B) != null;
            if (!self.a_done) {
                const maybe_a = if (a_has_error)
                    try self.a.next()
                else
                    self.a.next();
                if (maybe_a) |a|
                    return a;
                self.a_done = true;
            }
            return if (b_has_error)
                try self.b.next()
            else
                self.b.next();
        }
    };
}

/// Takes two iterators and creates a new iterator over both in sequence.
///
/// chain() will return a new iterator which will first iterate over values from
/// the first iterator and then over values from the second iterator.
///
/// In other words, it links two iterators together, in a chain. 🔗
pub fn chain(iter1: anytype, iter2: anytype) ChainIter(@TypeOf(iter1), @TypeOf(iter2)) {
    return .{ .a = iter1, .b = iter2, .a_done = false };
}

test "Chain" {
    var iter1 = sliceIter(u32, &.{ 1, 2, 3 });
    var iter2 = range(u32, 5, 8);
    var iter = chain(iter1, iter2);
    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 5), iter.next());
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, 7), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "Chain error in iter1" {
    var iter1 = TestErrorIter.init(3);
    var iter2 = range(usize, 5, 8);
    var iter = chain(iter1, iter2);
    try testing.expectEqual(usize, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?usize, 0), try iter.next());
    try testing.expectEqual(@as(?usize, 1), try iter.next());
    try testing.expectEqual(@as(?usize, 2), try iter.next());
    try testing.expectError(error.TestErrorIterError, iter.next());
}

test "Chain error in iter2" {
    var iter1 = range(usize, 5, 8);
    var iter2 = TestErrorIter.init(3);
    var iter = chain(iter1, iter2);
    try testing.expectEqual(usize, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?usize, 5), try iter.next());
    try testing.expectEqual(@as(?usize, 6), try iter.next());
    try testing.expectEqual(@as(?usize, 7), try iter.next());
    try testing.expectEqual(@as(?usize, 0), try iter.next());
    try testing.expectEqual(@as(?usize, 1), try iter.next());
    try testing.expectEqual(@as(?usize, 2), try iter.next());
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
