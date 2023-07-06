const std = @import("std");
const testing = std.testing;
const Child = std.meta.Child;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const SliceIter = itertools.SliceIter;

/// Returns the return type to be used in `toSlice`
pub fn ToSlice(comptime Iter: type) type {
    return if (IterError(Iter)) |ES|
        (error{IterTooLong} || ES)![]Item(Iter)
    else
        error{IterTooLong}![]Item(Iter);
}

/// Collects the items of an iterator in a buffer slice.
///
/// If the buffer is not big enough `error.IterTooLong` is returned. Otherwise, the slice containing
/// all items is returned. This slice will always be at the start of buffer.
pub fn toSlice(
    iter: anytype,
    buffer: []Item(Child(@TypeOf(iter))),
) ToSlice(Child(@TypeOf(iter))) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var i: usize = 0;
    while (if (has_error) try iter.next() else iter.next()) |item| : (i += 1) {
        if (i >= buffer.len) return error.IterTooLong;
        buffer[i] = item;
    }
    return buffer[0..i];
}

test "toSlice" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    var buffer: [10]u32 = undefined;

    try testing.expectEqualSlices(u32, slice, try toSlice(&iter, &buffer));

    var empty_buffer: [0]u32 = .{};
    var iter2 = SliceIter(u32).init(slice);
    try testing.expectError(error.IterTooLong, toSlice(&iter2, &empty_buffer));
}

test "toSlice error" {
    var iter = TestErrorIter.init(5);
    var buffer: [10]usize = undefined;

    try testing.expectError(error.TestErrorIterError, toSlice(&iter, &buffer));
}

/// Returns the return type to be used in `toSliceAlloc`
pub fn ToSliceAlloc(comptime Iter: type) type {
    return if (IterError(Iter)) |ES|
        (Allocator.Error || ES)![]Item(Iter)
    else
        Allocator.Error![]Item(Iter);
}

/// Collects the items of an iterator in an allocated slice.
pub fn toSliceAlloc(
    iter: anytype,
    allocator: Allocator,
) ToSliceAlloc(Child(@TypeOf(iter))) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var list = ArrayList(Item(Child(@TypeOf(iter)))).init(allocator);
    defer list.deinit();
    while (if (has_error) try iter.next() else iter.next()) |item| {
        try list.append(item);
    }
    return try list.toOwnedSlice();
}

test "toSliceAlloc" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    const allocated = try toSliceAlloc(&iter, testing.allocator);
    defer testing.allocator.free(allocated);

    try testing.expectEqualSlices(u32, slice, allocated);
}

test "toSliceAlloc error" {
    var iter = TestErrorIter.init(5);

    try testing.expectError(error.TestErrorIterError, toSliceAlloc(&iter, testing.allocator));
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
