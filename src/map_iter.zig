const std = @import("std");
const testing = std.testing;

const itertools = @import("main.zig");
const Item = itertools.Item;
const IterError = itertools.IterError;
const sliceIter = itertools.sliceIter;

fn validateClosure(comptime Closure: type) std.builtin.Type.Fn {
    switch (@typeInfo(Closure)) {
        .Struct, .Enum, .Union, .Opaque => {
            if (!@hasDecl(Closure, "apply")) {
                @compileError("map closure must have a declaration");
            }
            switch (@typeInfo(@TypeOf(@field(Closure, "apply")))) {
                .Fn => |Fn| {
                    if (Fn.params.len != 2) {
                        @compileError("map closure's apply function must accept exactly 2 arguments");
                    }
                    return Fn;
                },
                else => @compileError("map closure's apply declaration must be a function"),
            }
        },
        else => @compileError("mapper must be a function or a closure"),
    }
}

/// Iter type for mapping another iterator with a function
///
/// See `map` for more info.
pub fn MapIter(comptime BaseIter: type, comptime Func: type) type {
    const Source = Item(BaseIter);
    switch (@typeInfo(Func)) {
        .Fn => |Fn| {
            if (Fn.params.len != 1) {
                @compileError("map func must be a unary function");
            }
            if (Fn.params[0].type.? != Source) {
                @compileError("map func's argument must be iter's item type");
            }
            const Dest = Fn.return_type orelse @compileError("map func must have a return type");

            return struct {
                const Self = @This();

                base_iter: BaseIter,
                func: *const Func,

                pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

                pub fn next(self: *Self) Next {
                    const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                        try self.base_iter.next()
                    else
                        self.base_iter.next();

                    return if (maybe_item) |item|
                        self.func(item)
                    else
                        null;
                }
            };
        },
        .Pointer => |Pointer| if (Pointer.size == .One) {
            switch (@typeInfo(Pointer.child)) {
                .Fn => |Fn| {
                    if (Fn.params.len != 1) {
                        @compileError("map func must be a unary function");
                    }
                    if (Fn.params[0].type.? != Source) {
                        @compileError("map func's argument must be iter's item type");
                    }
                    const Dest = Fn.return_type orelse @compileError("map func must have a return type");

                    return struct {
                        const Self = @This();

                        base_iter: BaseIter,
                        func: Func,

                        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

                        pub fn next(self: *Self) Next {
                            const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                                try self.base_iter.next()
                            else
                                self.base_iter.next();

                            return if (maybe_item) |item|
                                self.func(item)
                            else
                                null;
                        }
                    };
                },
                .Pointer => |Pointer2| switch (@typeInfo(Pointer2.child)) {
                    .Fn => |Fn| {
                        if (Fn.params.len != 1) {
                            @compileError("map func must be a unary function");
                        }
                        if (Fn.params[0].type.? != Source) {
                            @compileError("map func's argument must be iter's item type");
                        }
                        const Dest = Fn.return_type orelse @compileError("map func must have a return type");

                        return struct {
                            const Self = @This();

                            base_iter: BaseIter,
                            func: Func,

                            pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

                            pub fn next(self: *Self) Next {
                                const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                                    try self.base_iter.next()
                                else
                                    self.base_iter.next();

                                return if (maybe_item) |item|
                                    self.func.*(item)
                                else
                                    null;
                            }
                        };
                    },
                    else => @compileError("mapper must be a function or a closure"),
                },
                else => {
                    const Fn = validateClosure(Pointer.child);
                    if (Fn.params[0].type.? != Func) {
                        @compileLog(Fn.params[0].type, Func);
                        @compileError("map closure's apply function's first argument must be the closure or " ++
                            "single item pointer to a closure");
                    }
                    const Dest = Fn.return_type orelse @compileError("map func must have a return type");

                    return struct {
                        const Self = @This();

                        base_iter: BaseIter,
                        func: Func,

                        pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

                        pub fn next(self: *Self) Next {
                            const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                                try self.base_iter.next()
                            else
                                self.base_iter.next();

                            return if (maybe_item) |item|
                                self.func.apply(item)
                            else
                                null;
                        }
                    };
                },
            }
        } else {
            @compileError("map func must be passed as a pointer to one item or the instance itself (closure or fn)");
        },
        else => {
            const Fn = validateClosure(Func);
            if (Fn.params[0].type.? != Func) {
                @compileError("map closure's apply function's first argument must be the closure or " ++
                    "single item pointer to a closure");
            }
            const Dest = Fn.return_type orelse @compileError("map func must have a return type");

            return struct {
                const Self = @This();

                base_iter: BaseIter,
                func: Func,

                pub const Next = if (IterError(BaseIter)) |ES| ES!?Dest else ?Dest;

                pub fn next(self: *Self) Next {
                    const maybe_item = if (@typeInfo(Next) == .ErrorUnion)
                        try self.base_iter.next()
                    else
                        self.base_iter.next();

                    return if (maybe_item) |item|
                        self.func.apply(item)
                    else
                        null;
                }
            };
        },
    }
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
) MapIter(@TypeOf(iter), @TypeOf(func)) {
    return .{ .base_iter = iter, .func = func };
}

test "MapIter" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

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

test "MapIter variable fn pointer" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    const functions = struct {
        pub fn double(x: u32) u64 {
            return 2 * x;
        }

        pub fn addOne(x: u32) u64 {
            return x + 1;
        }
    };

    var function = &functions.double;
    var iter = map(slice_iter, &function);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 2), iter.next());
    function = functions.addOne;
    try testing.expectEqual(@as(?u64, 3), iter.next());
    function = functions.double;
    try testing.expectEqual(@as(?u64, 6), iter.next());
    function = functions.addOne;
    try testing.expectEqual(@as(?u64, 5), iter.next());
    function = functions.double;
    try testing.expectEqual(@as(?u64, null), iter.next());
    function = functions.addOne;
    try testing.expectEqual(@as(?u64, null), iter.next());
}

test "MapIter immutable fn pointer" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    const functions = struct {
        pub fn double(x: u32) u64 {
            return 2 * x;
        }
    };

    var iter = map(slice_iter, &functions.double);

    try testing.expectEqual(u64, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u64, 2), iter.next());
    try testing.expectEqual(@as(?u64, 4), iter.next());
    try testing.expectEqual(@as(?u64, 6), iter.next());
    try testing.expectEqual(@as(?u64, 8), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
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

test "MapIter value closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    const bias: u32 = 1;
    const Closure = struct {
        enclosed: u32,
        pub fn apply(self: @This(), x: u32) u65 {
            return x * 2 + self.enclosed;
        }
    };
    const closure = Closure{ .enclosed = bias };

    var iter = map(slice_iter, closure);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
}

test "MapIter reference closure" {
    const slice: []const u32 = &.{ 1, 2, 3, 4 };
    var slice_iter = sliceIter(u32, slice);

    var acc: u32 = 0;
    const Closure = struct {
        enclosed: *u32,
        pub fn apply(self: *@This(), x: u32) u65 {
            if (x % 2 == 0) {
                self.enclosed.* += x;
            }
            return x * 2 + 1;
        }
    };
    var closure = Closure{ .enclosed = &acc };

    var iter = map(slice_iter, &closure);

    try testing.expectEqual(u65, Item(@TypeOf(iter)));
    try testing.expectEqual(@as(?u65, 3), iter.next());
    try testing.expectEqual(@as(?u65, 5), iter.next());
    try testing.expectEqual(@as(?u65, 7), iter.next());
    try testing.expectEqual(@as(?u65, 9), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(?u65, null), iter.next());
    try testing.expectEqual(@as(u32, 6), acc);
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
