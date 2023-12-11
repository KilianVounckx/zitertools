const it = @import("main.zig");
const Item = it.Item;
const IterError = it.IterError;

pub fn iterMethods(iter: anytype) IterMethods(@TypeOf(iter)) {
    return .{ .iter = iter };
}

pub fn IterMethods(comptime Iter: type) type {
    return struct {
        const Self = @This();
        iter: Iter,

        pub const Next = if (IterError(Iter)) |ES| ES!?Item(Iter) else ?Item(Iter);

        pub fn next(self: *Self) Next {
            return self.iter.next();
        }

        pub fn nth(self: *Self, n: usize) it.Nth(Iter) {
            return it.nth(&self.iter, n);
        }

        // pub fn peekable

        pub fn map(self: Self, comptime func: anytype) IterMethods(it.MapIter(
            Iter,
            it.validateMapFn(Item(Iter), func),
        )) {
            return .{ .iter = it.map(self.iter, func) };
        }

        pub fn mapContext(
            self: Self,
            context: anytype,
            comptime func: anytype,
        ) IterMethods(it.MapContextIter(
            Iter,
            it.validateMapContextFn(Item(Iter), @TypeOf(context), func),
        )) {
            return .{ .iter = it.mapContext(self.iter, context, func) };
        }

        pub fn filter(
            self: Self,
            comptime predicate: fn (*const Item(Iter)) bool,
        ) IterMethods(it.FilterIter(Iter, predicate)) {
            return .{ .iter = it.filter(self.iter, predicate) };
        }

        pub fn filterContext(
            self: Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), *const Item(Iter)) bool,
        ) IterMethods(it.FilterContextIter(Iter, @TypeOf(context), predicate)) {
            return .{ .iter = it.filterContext(self.iter, context, predicate) };
        }

        pub fn filterMap(
            self: Self,
            comptime func: anytype,
        ) IterMethods(it.FilterMapIter(
            Iter,
            it.validateFilterMapFn(Item(Iter), func),
        )) {
            return .{ .iter = it.filterMap(self.iter, func) };
        }

        pub fn filterMapContext(
            self: Self,
            context: anytype,
            comptime func: anytype,
        ) IterMethods(it.FilterMapContextIter(
            Iter,
            @TypeOf(context),
            it.validateFilterMapContextFn(Item(Iter), @TypeOf(context), func),
        )) {
            return .{ .iter = it.filterMapContext(self.iter, context, func) };
        }

        pub fn find(
            self: *Self,
            comptime predicate: fn (*const Item(Iter)) bool,
        ) it.Find(Iter, predicate) {
            return it.find(&self.iter, predicate);
        }

        pub fn findContext(
            self: *Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), *const Item(Iter)) bool,
        ) it.Find(Iter, @TypeOf(context), predicate) {
            return it.findContext(&self.iter, context, predicate);
        }

        pub fn chain(self: Self, other: anytype) IterMethods(it.ChainIter(Iter, @TypeOf(other))) {
            return .{ .iter = it.chain(self.iter, other) };
        }

        pub fn zip(self: Self, other: anytype) IterMethods(it.ZipIter(struct { Iter, @TypeOf(other) })) {
            return .{ .iter = it.zip(.{ self.iter, other }) };
        }

        pub fn skip(self: Self, to_skip: usize) IterMethods(it.SkipIter(Iter)) {
            return .{ .iter = it.skip(self.iter, to_skip) };
        }

        pub fn skipWhile(
            self: Self,
            comptime predicate: fn (*const Item(Iter)) bool,
        ) IterMethods(it.SkipWhileIter(Iter, predicate)) {
            return .{ .iter = it.skipWhile(self.iter, predicate) };
        }

        pub fn skipWhileContext(
            self: Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), *const Item(Iter)) bool,
        ) IterMethods(it.SkipWhileContextIter(Iter, @TypeOf(context), predicate)) {
            return .{ .iter = it.skipWhileContext(self.iter, context, predicate) };
        }

        pub fn take(self: Self, to_take: usize) IterMethods(it.TakeIter(Iter)) {
            return .{ .iter = it.take(self.iter, to_take) };
        }

        pub fn takeWhile(
            self: Self,
            comptime predicate: fn (Item(Iter)) bool,
        ) IterMethods(it.TakeWhileIter(Iter, predicate)) {
            return .{ .iter = it.takeWhile(self.iter, predicate) };
        }

        pub fn takeWhileContext(
            self: Self,
            context: anytype,
            comptime predicate: fn (@TypeOf(context), Item(Iter)) bool,
        ) IterMethods(it.TakeWhileContextIter(Iter, @TypeOf(context), predicate)) {
            return .{ .iter = it.takeWhileContext(self.iter, context, predicate) };
        }

        pub inline fn fold(
            self: Self,
            init: anytype,
            comptime func: fn (@TypeOf(init), Item(Iter)) @TypeOf(init),
        ) it.Fold(Iter, @TypeOf(init)) {
            return it.fold(self.iter, init, func);
        }

        pub inline fn foldContext(
            self: Self,
            context: anytype,
            init: anytype,
            comptime func: fn (@TypeOf(context), @TypeOf(init), Item(Iter)) @TypeOf(init),
        ) it.Fold(Iter, @TypeOf(context), @TypeOf(init)) {
            return it.foldContext(self.iter, context, init, func);
        }

        pub inline fn reduce(
            self: Self,
            comptime func: fn (Item(Iter), Item(Iter)) Item(Iter),
        ) it.Reduce(Iter) {
            return it.reduce(self.iter, func);
        }

        pub inline fn reduceContext(
            self: Self,
            context: anytype,
            comptime func: fn (@TypeOf(context), Item(Iter), Item(Iter)) Item(Iter),
        ) it.Reduce(Iter) {
            return it.reduceContext(self.iter, context, func);
        }

        pub inline fn count(self: Self) usize {
            return it.count(self.iter);
        }

        pub inline fn sum(self: Self, comptime Dest: ?type) it.Sum(Iter, Dest) {
            return it.sum(Dest, self.iter);
        }

        pub inline fn product(self: Self, comptime Dest: ?type) it.Product(Iter, Dest) {
            return it.product(Dest, self.iter);
        }

        pub inline fn forEach(
            self: Self,
            comptime func: fn (Item(Iter)) void,
        ) void {
            return it.forEach(self.iter, func);
        }

        pub inline fn forEachContext(
            self: Self,
            context: anytype,
            comptime func: fn (@TypeOf(context), Item(Iter)) void,
        ) void {
            return it.forEachContext(self.iter, context, func);
        }
    };
}

const testing = @import("std").testing;

test "IterMethods" {
    var iter = iterMethods(it.sliceIter(u8, &.{ 1, 2, 3 }))
        .map(struct {
        fn double(item: u8) u9 {
            return item * 2;
        }
    }.double);
    try testing.expectEqual(@as(?u9, 2), iter.next());
    try testing.expectEqual(@as(?u9, 4), iter.next());
    try testing.expectEqual(@as(?u9, 6), iter.next());
    try testing.expectEqual(@as(?u9, null), iter.next());
}
