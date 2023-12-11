const std = @import("std");
const testing = std.testing;

const slice_iter = @import("slice_iter.zig");
pub const SliceIter = slice_iter.SliceIter;
pub const sliceIter = slice_iter.sliceIter;
const range_iter = @import("range_iter.zig");
pub const range = range_iter.range;
pub const RangeIter = range_iter.RangeIter;
const chain_iter = @import("chain_iter.zig");
pub const chain = chain_iter.chain;
pub const ChainIter = chain_iter.ChainIter;
const cycle_iter = @import("cycle_iter.zig");
pub const cycle = cycle_iter.cycle;
pub const CycleIter = cycle_iter.CycleIter;
const enumerate_iter = @import("enumerate_iter.zig");
pub const enumerate = enumerate_iter.enumerate;
pub const EnumerateIter = enumerate_iter.EnumerateIter;
const empty_iter = @import("empty_iter.zig");
pub const empty = empty_iter.empty;
pub const EmptyIter = empty_iter.EmptyIter;
const map_iter = @import("map_iter.zig");
pub const map = map_iter.map;
pub const validateMapFn = map_iter.validateMapFn;
pub const mapContext = map_iter.mapContext;
pub const validateMapContextFn = map_iter.validateMapContextFn;
pub const MapIter = map_iter.MapIter;
pub const MapContextIter = map_iter.MapContextIter;
const filter_iter = @import("filter_iter.zig");
pub const filter = filter_iter.filter;
pub const filterContext = filter_iter.filterContext;
pub const FilterIter = filter_iter.FilterIter;
pub const FilterContextIter = filter_iter.FilterContextIter;
const to_slice = @import("to_slice.zig");
pub const ToSlice = to_slice.ToSlice;
pub const toSlice = to_slice.toSlice;
pub const ToSliceAlloc = to_slice.ToSliceAlloc;
pub const toSliceAlloc = to_slice.toSliceAlloc;
const fold_namespace = @import("fold.zig");
pub const fold = fold_namespace.fold;
pub const foldContext = fold_namespace.foldContext;
pub const Fold = fold_namespace.Fold;
const reduce_namespace = @import("reduce.zig");
pub const reduce = reduce_namespace.reduce;
pub const reduceContext = reduce_namespace.reduceContext;
pub const Reduce = reduce_namespace.Reduce;
const filter_map_iter = @import("filter_map_iter.zig");
pub const filterMap = filter_map_iter.filterMap;
pub const filterMapContext = filter_map_iter.filterMapContext;
pub const FilterMapIter = filter_map_iter.FilterMapIter;
pub const FilterMapContextIter = filter_map_iter.FilterMapContextIter;
const find_namespace = @import("find.zig");
pub const find = find_namespace.find;
pub const findContext = find_namespace.findContext;
pub const Find = find_namespace.Find;
const flatten_iter = @import("flatten_iter.zig");
pub const flatten = flatten_iter.flatten;
pub const FlattenIter = flatten_iter.FlattenIter;
const once_iter = @import("once_iter.zig");
pub const once = once_iter.once;
pub const OnceIter = once_iter.OnceIter;
const peekable_iter = @import("peekable_iter.zig");
pub const peekable = peekable_iter.peekable;
pub const PeekableIter = peekable_iter.PeekableIter;
const repeat_iter = @import("repeat_iter.zig");
pub const repeat = repeat_iter.repeat;
pub const RepeatIter = repeat_iter.RepeatIter;
const skip_iter = @import("skip_iter.zig");
pub const skip = skip_iter.skip;
pub const SkipIter = skip_iter.SkipIter;
const skip_while_iter = @import("skip_while_iter.zig");
pub const skipWhile = skip_while_iter.skipWhile;
pub const skipWhileContext = skip_while_iter.skipWhileContext;
pub const SkipWhileIter = skip_while_iter.SkipWhileIter;
pub const SkipWhileContextIter = skip_while_iter.SkipWhileContextIter;
const successors_iter = @import("successors_iter.zig");
pub const successors = successors_iter.successors;
pub const SuccessorsIter = successors_iter.SuccessorsIter;
const take_iter = @import("take_iter.zig");
pub const take = take_iter.take;
pub const TakeIter = take_iter.TakeIter;
const take_while_iter = @import("take_while_iter.zig");
pub const takeWhile = take_while_iter.takeWhile;
pub const takeWhileContext = take_while_iter.takeWhileContext;
pub const TakeWhileIter = take_while_iter.TakeWhileIter;
pub const TakeWhileContextIter = take_while_iter.TakeWhileContextIter;
const zip_iter = @import("zip_iter.zig");
pub const zip = zip_iter.zip;
pub const ZipIter = zip_iter.ZipIter;
const sum_namespace = @import("sum.zig");
pub const sum = sum_namespace.sum;
pub const Sum = sum_namespace.Sum;
const product_namespace = @import("product.zig");
pub const product = product_namespace.product;
pub const Product = product_namespace.Product;
const for_each = @import("for_each.zig");
pub const forEach = for_each.forEach;
pub const forEachContext = for_each.forEachContext;
const iter_methods = @import("iter_methods.zig");
pub const iterMethods = iter_methods.iterMethods;
pub const IterMethods = iter_methods.IterMethods;

test {
    testing.refAllDeclsRecursive(@This());
}

pub fn count(iter: anytype) usize {
    var result = 0;
    while (iter.next()) |_| {
        result += 1;
    }
    return result;
}

/// Returns the type of item the iterator holds
///
/// # example
/// ```
/// var iter = std.mem.tokenize(u8, "hi there world", " ");
/// std.debug.assert(Item(@TypeOf(iter)) == []const u8);
/// ```
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
/// ```
/// var iter = std.mem.tokenize(u8, "hi there world", " ");
/// std.debug.assert(IterError(@TypeOf(iter)) == null);
/// ```
///
/// ```
/// var dir = someIterableDirFromSomewhere();
/// const walker = try dir.walk();
/// std.debug.assert(IterError(@TypeOf(walker)) == std.mem.Allocator.Error);
/// ```
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

test "tokenize" {
    const string = "hi there world";
    var tokens = std.mem.tokenizeAny(u8, string, " ");

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
