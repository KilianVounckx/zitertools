const std = @import("std");
const testing = std.testing;

pub const SliceIter = @import("slice_iter.zig").SliceIter;
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
pub const MapIter = map_iter.MapIter;
pub const MapDestType = map_iter.MapDestType;
const filter_iter = @import("filter_iter.zig");
pub const filter = filter_iter.filter;
pub const FilterIter = filter_iter.FilterIter;
const to_slice = @import("to_slice.zig");
pub const ToSlice = to_slice.ToSlice;
pub const toSlice = to_slice.toSlice;
pub const ToSliceAlloc = to_slice.ToSliceAlloc;
pub const toSliceAlloc = to_slice.toSliceAlloc;
const reduce_namespace = @import("reduce.zig");
pub const reduce = reduce_namespace.reduce;
pub const Reduce = reduce_namespace.Reduce;
pub const reduce1 = reduce_namespace.reduce1;
pub const Reduce1 = reduce_namespace.Reduce1;
const filter_map_iter = @import("filter_map_iter.zig");
pub const filterMap = filter_map_iter.filterMap;
pub const FilterMapIter = filter_map_iter.FilterMapIter;
pub const FilterMapDestType = filter_map_iter.FilterMapDestType;
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

test {
    testing.refAllDeclsRecursive(@This());
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
