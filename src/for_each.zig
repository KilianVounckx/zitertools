const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

pub fn ForEach(comptime Iter: type) type {
    return if (IterError(Iter)) |ES| ES!void else void;
}

pub fn forEach(
    iter: anytype,
    comptime callback: fn (Item(@TypeOf(iter))) void,
) ForEach(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    var mut_iter = iter;
    while (if (has_error) try mut_iter.next() else mut_iter.next()) |item| {
        callback(item);
    }
}

pub fn forEachContext(
    iter: anytype,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Item(@TypeOf(iter))) void,
) ForEach(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    var mut_iter = iter;
    while (if (has_error) try mut_iter.next() else mut_iter.next()) |item| {
        callback(context, item);
    }
}

const testing = @import("std").testing;

test "forEach" {
    const iter = sliceIter(u8, &.{ 1, 2, 3, 4, 5 });
    var sum: u8 = 0;

    forEachContext(
        iter,
        &sum,
        struct {
            fn callback(total: *u8, item: u8) void {
                total.* += item;
            }
        }.callback,
    );

    try testing.expect(sum == 15);
}
