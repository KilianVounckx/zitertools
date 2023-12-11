const std = @import("std");
const testing = std.testing;
const Type = std.builtin.Type;
const Struct = std.builtin.Type.Struct;
const StructField = std.builtin.Type.StructField;
const ErrorSet = std.builtin.Type.ErrorSet;
const Error = std.builtin.Type.Error;

const itertools = @import("main.zig");
const Item = itertools.Item;
const SliceIter = itertools.SliceIter;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;
const range = itertools.range;
const iterMethods = itertools.iterMethods;

/// An iterator that iterates two other iterators simultaneously.
///
/// See `zip` for more info.
pub fn ZipIter(comptime Iters: type) type {
    return struct {
        const Self = @This();

        iters: Iters,

        pub const Item: type = ZipIterItem(Iters);
        pub const ErrorSet: ?type = ZipIterErrorSet(Iters);
        pub const Next = if (Self.ErrorSet) |ES| ES!?Self.Item else ?Self.Item;

        pub fn next(self: *Self) Next {
            var item: Self.Item = undefined;
            inline for (@typeInfo(Iters).Struct.fields) |iter_field| {
                if (iter_field.is_comptime) {
                    continue;
                }

                const has_error = comptime IterError(iter_field.type) != null;
                const maybe_item = if (has_error)
                    try @field(self.iters, iter_field.name).next()
                else
                    @field(self.iters, iter_field.name).next();
                @field(item, iter_field.name) = maybe_item orelse return null;
            }
            return item;
        }
    };
}

pub fn ZipIterItem(comptime Iters: type) type {
    const iters_type_info = @typeInfo(Iters);
    const total_fields = blk: {
        var total_fields = 0;
        for (iters_type_info.Struct.fields) |field| {
            if (field.is_comptime) {
                continue;
            }
            total_fields += 1;
        }
        break :blk total_fields;
    };
    if (iters_type_info != .Struct) {
        @compileError("expected tuple or struct, found '" ++ @typeName(Iters) ++ "'");
    }
    return @Type(.{
        .Struct = Struct{
            .layout = .Auto,
            .fields = &blk: {
                var fields: [total_fields]StructField = undefined;
                var i = 0; // manual counter because of filtering out of comptime fields
                for (iters_type_info.Struct.fields) |field| {
                    if (field.is_comptime) {
                        continue;
                    }
                    fields[i] = std.builtin.Type.StructField{
                        .name = field.name,
                        .type = Item(field.type),
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = 0,
                    };
                    i += 1;
                }
                break :blk fields;
            },
            .decls = &.{},
            .is_tuple = iters_type_info.Struct.is_tuple,
        },
    });
}

pub fn ZipIterErrorSet(comptime Iters: type) ?type {
    const iters_type_info = @typeInfo(Iters);
    if (iters_type_info != .Struct) {
        @compileError("expected tuple or struct, found '" ++ @typeName(Iters) ++ "'");
    }

    var ES: ?type = null;
    for (iters_type_info.Struct.fields) |field| {
        if (field.is_comptime) {
            continue;
        }
        ES = ES orelse error{} || (IterError(field.type) orelse continue);
    }
    return ES;
}

/// ‘Zips up’ several iterators into a single iterator of tuples/structs.
///
/// `zip()` returns a new iterator that will iterate over several other iterators,
/// returning a tuple/struct of items where each field corresponts
/// to the field in the tuple/struct of iteratos.
///
/// In other words, it zips several iterators together, into a single one.
///
/// If either iterator returns null, next from the zipped iterator will return
/// null. If the zipped iterator has no more elements to return then each
/// further attempt to advance it will first try to advance the first iterator
/// at most one time and if it still yielded an item try to advance the second
/// iterator at most one time and so on.
pub fn zip(iters: anytype) ZipIter(@TypeOf(iters)) {
    return .{ .iters = iters };
}

test "zip tuple" {
    var iter1 = sliceIter(u32, &.{ 1, 2, 3 });
    var iter2 = range(u64, 5, 8);
    var iter = zip(.{ iter1, iter2 });
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

test "zip struct" {
    var iter1 = sliceIter(u32, &.{ 1, 2, 3 });
    var iter2 = range(u64, 5, 8);
    var iter = zip(.{ .first = iter1, .second = iter2 });
    try testing.expectEqual(@TypeOf(iter).Item, Item(@TypeOf(iter)));
    const v1 = iter.next().?;
    try testing.expectEqual(@as(u32, 1), v1.first);
    try testing.expectEqual(@as(u64, 5), v1.second);
    const v2 = iter.next().?;
    try testing.expectEqual(@as(u32, 2), v2.first);
    try testing.expectEqual(@as(u64, 6), v2.second);
    const v3 = iter.next().?;
    try testing.expectEqual(@as(u32, 3), v3.first);
    try testing.expectEqual(@as(u64, 7), v3.second);
    try testing.expectEqual(@as(?Item(@TypeOf(iter)), null), iter.next());
}

test "zip error first" {
    var iter1 = TestErrorIter.init(3);
    var iter2 = range(u64, 5, 8);
    var iter = zip(.{ iter1, iter2 });
    try testing.expectEqual(@TypeOf(iter).Item, Item(@TypeOf(iter)));
    const v1 = (try iter.next()).?;
    try testing.expectEqual(@as(usize, 0), v1.@"0");
    try testing.expectEqual(@as(u64, 5), v1.@"1");
    const v2 = (try iter.next()).?;
    try testing.expectEqual(@as(usize, 1), v2.@"0");
    try testing.expectEqual(@as(u64, 6), v2.@"1");
    const v3 = (try iter.next()).?;
    try testing.expectEqual(@as(usize, 2), v3.@"0");
    try testing.expectEqual(@as(u64, 7), v3.@"1");
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
