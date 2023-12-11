const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;

pub fn ForEach(comptime Iter: type) type {
    return if (IterError(Iter)) |ES| ES!void else void;
}

pub fn forEach(
    iter: anytype,
    comptime callback: fn (Item(@TypeOf(iter))) void,
) ForEach(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        callback(item);
    }
}

pub fn forEachContext(
    iter: anytype,
    context: anytype,
    comptime callback: fn (@TypeOf(context), Item(@TypeOf(iter))) void,
) ForEach(@TypeOf(iter)) {
    const has_error = comptime IterError(@TypeOf(iter)) != null;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        callback(context, item);
    }
}
