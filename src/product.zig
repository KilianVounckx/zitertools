const std = @import("std");
const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const fold = itertools.fold;
const sliceIter = itertools.sliceIter;

pub fn Product(comptime Iter: type, comptime Dest: ?type) type {
    return if (IterError(Iter)) |ES| ES!(Dest orelse Item(Iter)) else (Dest orelse Item(Iter));
}

pub fn product(comptime Dest: ?type, iter: anytype) Product(@TypeOf(iter), Dest) {
    const T = Item(@TypeOf(iter));
    const mul = struct {
        fn mul(a: (Dest orelse T), b: T) (Dest orelse T) {
            return @as(Dest orelse T, a) * @as(Dest orelse T, b);
        }
    }.mul;

    const has_error = comptime IterError(@TypeOf(iter)) != null;

    const init = switch (@typeInfo(Dest orelse T)) {
        .Int, .Float => @as(Dest orelse T, 1),
        .Vector => @as(Dest orelse T, @splat(1)),
        else => @panic("sum: unsupported type"),
    };
    return (if (has_error) try fold(iter, init, mul) else fold(iter, init, mul));
}

const testing = @import("std").testing;

test "sum ints" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(u32, 120), product(null, sliceIter(u32, slice)));
}

test "mul u32 as u33" {
    const slice: []const u32 = &.{ std.math.maxInt(u32), 2 };
    try testing.expectEqual(@as(u33, std.math.maxInt(u33) - 1), product(u33, sliceIter(u32, slice)));
}

test "sum floats" {
    const slice: []const f32 = &.{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(f32, 120), product(null, sliceIter(f32, slice)));
}

test "sum vectors" {
    const slice: []const @Vector(2, u32) = &.{
        @Vector(2, u32){ 1, 2 },
        @Vector(2, u32){ 3, 4 },
        @Vector(2, u32){ 5, 6 },
    };
    try testing.expectEqual(@Vector(2, u32){ 15, 48 }, product(null, sliceIter(@Vector(2, u32), slice)));
}

test "sum empty" {
    const slice: []const u32 = &.{};
    try testing.expectEqual(@as(u32, 1), product(null, sliceIter(u32, slice)));

    const slice2: []const f32 = &.{};
    try testing.expectEqual(@as(f32, 1), product(null, sliceIter(f32, slice2)));

    const slice3: []const @Vector(2, u32) = &.{};
    try testing.expectEqual(@Vector(2, u32){ 1, 1 }, product(null, sliceIter(@Vector(2, u32), slice3)));
}

test "sum error" {
    const iter = TestErrorIter.init(5);
    try testing.expectError(error.TestErrorIterError, product(null, iter));
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
