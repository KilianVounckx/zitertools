const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;

/// Returns the return type of the `find`/`findContext` function.
pub fn Find(comptime Iter: type) type {
    return if (IterError(Iter)) |ES| ES!?Item(Iter) else ?Item(Iter);
}

/// Searches for an element in an iterator that satisfies the given predicate.
///
/// Find is short-circuiting, i.e. it will stop processing as soon as the predicate returns true.
///
/// Note that `find(iter, f)` is equivalent to `filter(iter, f).next()`.
///
/// You can still use the iterator after calling this function.
pub fn find(
    iter: anytype,
    comptime predicate: fn (*const Item(@typeInfo(@TypeOf(iter)).Pointer.child)) bool,
) Find(@typeInfo(@TypeOf(iter)).Pointer.child) {
    const has_error = comptime IterError(@typeInfo(@TypeOf(iter)).Pointer.child) != null;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        if (predicate(&item)) return item;
    }
    return null;
}

/// Searches for an element in an iterator that satisfies the given predicate with context.
///
/// Find is short-circuiting, i.e. it will stop processing as soon as the predicate returns true.
///
/// Note that `findContext(iter, c, f)` is equivalent to `filterContext(iter, c, f).next()`.
///
/// You can still use the iterator after calling this function.
pub fn findContext(
    iter: anytype,
    context: anytype,
    comptime predicate: fn (@TypeOf(context), *const Item(@typeInfo(@TypeOf(iter)).Pointer.child)) bool,
) Find(@typeInfo(@TypeOf(iter)).Pointer.child) {
    const has_error = comptime IterError(@typeInfo(@TypeOf(iter)).Pointer.child) != null;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        if (predicate(context, &item)) return item;
    }
    return null;
}

const testing = @import("std").testing;

test "find 'o'" {
    const slice: []const u8 = "Hello, world!";
    var iter = itertools.sliceIter(u8, slice);

    const predicate = struct {
        fn predicate(item: *const u8) bool {
            return item.* == 'o';
        }
    }.predicate;
    try testing.expectEqual(@as(?u8, 'o'), find(&iter, predicate));
    try testing.expectEqual(@as(usize, 5), iter.index);
    try testing.expectEqual(@as(?u8, ','), iter.next());
    try testing.expectEqual(@as(?u8, 'o'), find(&iter, predicate));
    try testing.expectEqual(@as(usize, 9), iter.index);
    try testing.expectEqual(@as(?u8, null), find(&iter, predicate));
}
