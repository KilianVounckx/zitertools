const std = @import("std");
const testing = std.testing;
const ErrorSet = std.builtin.Type.ErrorSet;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Child = std.meta.Child;

/// Returns the type of item the iterator holds
///
/// # example
///     ```
///     var iter = std.mem.tokenize(u8, "hi there world", " ");
///     std.debug.assert(Item(@TypeOf(iter)) == []const u8);
///     ```
pub fn Item(comptime Iter: type) type {
    if (!@hasDecl(Iter, "next"))
        @compileError("iterator must have 'next' function");

    const func = switch (@typeInfo(@TypeOf(Iter.next))) {
        .Fn => |func| func,
        else => @compileError("iterator 'next' declaration must be a function"),
    };

    if (func.params.len != 1)
        @compileError("iterator 'next' function must take exactly one argument");

    const Param = func.params[0].type.?;
    if (Param != Iter and Param != *Iter and Param != *const Iter)
        @compileError(
            "iterator 'next' function's parameter type must be itself or a pointer to itself",
        );

    return switch (@typeInfo(func.return_type.?)) {
        .ErrorUnion => |eu| switch (@typeInfo(eu.payload)) {
            .Optional => |opt| opt.child,
            else => @compileError(
                "iterator 'next' function return type must be an optional" ++
                    " or an error union with optional payload",
            ),
        },
        .Optional => |opt| opt.child,
        else => @compileError(
            "iterator 'next' function return type must be an optional" ++
                " or an error union with optional payload",
        ),
    };
}

test "Item" {
    var iter = std.mem.tokenize(u8, "hi there world", " ");
    try testing.expectEqual([]const u8, Item(@TypeOf(iter)));
}

/// Returns the error set of the iterator's `next` function
///
/// This library supports iterators which can fail. This function will return the error set of
/// such iterators or `null` if they can't fail.
///
/// # examples
///     ```
///     var iter = std.mem.tokenize(u8, "hi there world", " ");
///     std.debug.assert(IterError(@TypeOf(iter)) == null);
///     ```
///
///     ```
///     var dir = someIterableDirFromSomewhere();
///     const walker = try dir.walk();
///     std.debug.assert(IterError(@TypeOf(walker)) ==
///     ```
pub fn IterError(comptime Iter: type) ?type {
    if (!@hasDecl(Iter, "next"))
        @compileError("iterator must have 'next' function");

    const func = switch (@typeInfo(@TypeOf(Iter.next))) {
        .Fn => |func| func,
        else => @compileError("iterator 'next' declaration must be a function"),
    };

    if (func.params.len != 1)
        @compileError("iterator 'next' function must take exactly one argument");

    const Param = func.params[0].type.?;
    if (Param != Iter and Param != *Iter and Param != *const Iter)
        @compileError(
            "iterator 'next' function's parameter type must be itself or a pointer to itself",
        );

    return switch (@typeInfo(func.return_type.?)) {
        .ErrorUnion => |eu| switch (@typeInfo(eu.payload)) {
            .Optional => eu.error_set,
            else => @compileError(
                "iterator 'next' function return type must be an optional" ++
                    " or an error union with optional payload",
            ),
        },
        .Optional => null,
        else => @compileError(
            "iterator 'next' function return type must be an optional" ++
                " or an error union with optional payload",
        ),
    };
}

test "IterError" {
    var iter = std.mem.tokenize(u8, "hi there world", " ");
    try testing.expectEqual(@as(?type, null), IterError(@TypeOf(iter)));

    const dir = testing.tmpIterableDir(.{}).iterable_dir;
    var walker = try dir.walk(testing.allocator);
    defer walker.deinit();
    try testing.expectEqual(
        @as(?type, @typeInfo(
            @typeInfo(@TypeOf(std.fs.IterableDir.Walker.next)).Fn.return_type.?,
        ).ErrorUnion.error_set),
        IterError(@TypeOf(walker)),
    );
}

/// Iter type for iterating over slice values
pub fn SliceIter(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []const T,
        index: usize = 0,

        /// Creates an iterator iterating over values in slice
        pub fn init(slice: []const T) Self {
            return .{ .slice = slice };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.slice.len)
                return null;
            self.index += 1;
            return self.slice[self.index - 1];
        }
    };
}

test "SliceIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, 4), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

/// Iter type for mapping another iterator with a function
///
/// See `map` for more info.
pub fn MapIter(comptime BaseIter: type, comptime Dest: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        func: *const fn (Item(BaseIter)) Dest,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            return if (maybe_item) |item|
                self.func(item)
            else
                null;
        }
    };
}

/// Returns the destination type for a given base iterator and function type
pub fn MapDestType(comptime BaseIter: type, comptime Func: type) type {
    const Source = Item(BaseIter);

    const func = switch (@typeInfo(Func)) {
        .Fn => |func| func,
        else => @compileError("map func must be a function"),
    };

    if (func.params.len != 1)
        @compileError("map func must be a unary function");

    if (func.params[0].type.? != Source)
        @compileError("map func's argument must be iter's item type");

    return func.return_type.?;
}

/// Returns a new iterator which maps items in iter using func as a function.
///
/// iter must be an iterator, meaning it has to be a type containing a next method which returns
/// an optional. func must be a unary function for which it's first argument type is the iterator's
/// item type.
pub fn map(
    iter: anytype,
    func: anytype,
) MapIter(@TypeOf(iter), MapDestType(@TypeOf(iter), @TypeOf(func))) {
    return .{ .base_iter = iter, .func = func };
}

test "MapIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = SliceIter(u32).init(slice);

    const functions = struct {
        pub fn double(x: u32) u64 {
            return 2 * x;
        }

        pub fn addOne(x: u64) u65 {
            return x + 1;
        }
    };

    var iter = map(map(slice_iter, functions.double), functions.addOne);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
}

test "MapIter error" {
    var test_iter = TestErrorIter.init(3);

    const double = struct {
        pub fn double(x: usize) u64 {
            return 2 * x;
        }
    }.double;

    var iter = map(test_iter, double);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 0), try iter.next());
    try testing.expectEqual(@as(?u64, 2), try iter.next());
    try testing.expectEqual(@as(?u64, 4), try iter.next());
    try testing.expectError(error.TestErrorIterError, iter.next());
}

/// Iter type for filtering another iterator with a predicate
///
/// See `filter` for more info.
pub fn FilterIter(comptime BaseIter: type) type {
    return struct {
        const Self = @This();

        base_iter: BaseIter,
        predicate: *const fn (Item(BaseIter)) bool,

        pub const Next = if (IterError(BaseIter)) |ES| ES!?Item(BaseIter) else ?Item(BaseIter);

        pub fn next(self: *Self) Next {
            const has_error = comptime IterError(BaseIter) != null;
            const maybe_item = if (has_error)
                try self.base_iter.next()
            else
                self.base_iter.next();
            const item = maybe_item orelse return null;
            if (self.predicate(item))
                return item;
            return self.next();
        }
    };
}

/// Returns a new iterator which filters items in iter with predicate
///
/// iter must be an iterator, meaning it has to be a type containing a next method which returns
/// an optional.
pub fn filter(
    iter: anytype,
    predicate: *const fn (Item(@TypeOf(iter))) bool,
) FilterIter(@TypeOf(iter)) {
    return .{ .base_iter = iter, .predicate = predicate };
}

test "FilterIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var slice_iter = SliceIter(u32).init(slice);

    const predicates = struct {
        pub fn even(x: u32) bool {
            return x % 2 == 0;
        }

        pub fn big(x: u32) bool {
            return x > 4;
        }
    };

    var iter = filter(filter(slice_iter, predicates.even), predicates.big);

    try testing.expectEqual(u32, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u32, 6), iter.next());
    try testing.expectEqual(@as(?u32, 8), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "FilterIter error" {
    var test_iter = TestErrorIter.init(5);

    const even = struct {
        pub fn even(x: usize) bool {
            return x % 2 == 0;
        }
    }.even;

    var iter = filter(test_iter, even);

    try testing.expectEqual(usize, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?usize, 0), try iter.next());
    try testing.expectEqual(@as(?usize, 2), try iter.next());
    try testing.expectEqual(@as(?usize, 4), try iter.next());
    try testing.expectError(error.TestErrorIterError, iter.next());
}

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

/// Returns the return type to be used in `reduce`
pub fn Reduce(comptime Iter: type, comptime T: type) type {
    return if (IterError(Iter)) |ES|
        ES!T
    else
        T;
}

/// Applies a binary operator between all items in iter with an initial element.
///
/// Also know as fold in functional languages.
pub fn reduce(
    iter: anytype,
    comptime T: type,
    func: *const fn (T, Item(Child(@TypeOf(iter)))) T,
    init: T,
) Reduce(Child(@TypeOf(iter)), T) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    var res = init;
    while (if (has_error) try iter.next() else iter.next()) |item| {
        res = func(res, item);
    }
    return res;
}

test "reduce" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    const add = struct {
        fn add(x: u64, y: u32) u64 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(u64, 10), reduce(&iter, u64, add, 0));
}

test "reduce error" {
    var iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: u64, y: usize) u64 {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, reduce(&iter, u64, add, 0));
}

/// Returns the return type to be used in `reduce1`
pub fn Reduce1(comptime Iter: type) type {
    return if (IterError(Iter)) |ES|
        (error{EmptyIterator} || ES)!Item(Iter)
    else
        error{EmptyIterator}!Item(Iter);
}

/// Applies a binary operator between all items in iter with no initial element.
///
/// If the iterator is empty `error.EmptyIter` is returned.
///
/// Also know as fold1 in functional languages.
pub fn reduce1(
    iter: anytype,
    func: *const fn (
        Item(Child(@TypeOf(iter))),
        Item(Child(@TypeOf(iter))),
    ) Item(Child(@TypeOf(iter))),
) Reduce1(Child(@TypeOf(iter))) {
    const has_error = comptime IterError(Child(@TypeOf(iter))) != null;
    const maybe_init = if (has_error) try iter.next() else iter.next();
    const init = maybe_init orelse return error.EmptyIter;
    return reduce(iter, Item(Child(@TypeOf(iter))), func, init);
}

test "reduce1" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var iter = SliceIter(u32).init(slice);

    const add = struct {
        fn add(x: u32, y: u32) u32 {
            return x + y;
        }
    }.add;

    try testing.expectEqual(@as(u32, 10), try reduce1(&iter, add));
    try testing.expectError(error.EmptyIter, reduce1(&iter, add));
}

test "reduce1 error" {
    var iter = TestErrorIter.init(5);

    const add = struct {
        fn add(x: usize, y: usize) usize {
            return x + y;
        }
    }.add;

    try testing.expectError(error.TestErrorIterError, reduce1(&iter, add));
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

test "chaining" {
    const functions = struct {
        fn thrice(x: u32) u64 {
            return x * 3;
        }
        fn even(x: u64) bool {
            return x % 2 == 0;
        }
        fn add(x: u128, y: u64) u128 {
            return x + y;
        }
    };

    const slice: []const u32 = &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var iter =
        filter(
        map(
            SliceIter(u32).init(slice),
            functions.thrice,
        ), // 0, 3, 6, 9, 12, 15, 18, 21, 24, 27
        functions.even,
    ); // 0, 6, 12, 18, 24
    const result = reduce(
        &iter,
        u128,
        functions.add,
        42,
    ); // 102

    try testing.expectEqual(@as(u128, 102), result);
}

test "tokenize" {
    const string = "hi there world";
    var tokens = std.mem.tokenize(u8, string, " ");

    const length = struct {
        fn length(x: []const u8) usize {
            return x.len;
        }
    }.length;

    var iter = map(tokens, length);
    var buffer: [10]usize = undefined;
    const lengths = try toSlice(&iter, &buffer);

    try testing.expectEqualSlices(usize, &.{ 2, 5, 5 }, lengths);
}
