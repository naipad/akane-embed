const std = @import("std");
const my_bundle = @import("my_bundle");
const other_bundle = @import("other_bundle");

pub fn main(init: std.process.Init) !void {
    const data = try my_bundle.extract(init.arena.allocator());
    const other_data = try other_bundle.extract(init.arena.allocator());

    try expectEqual("A - Apple", my_bundle.files.@"A.txt".bytes(data));
    try expectEqual("B - Banana", my_bundle.files.@"B.txt".bytes(data));
    try expectEqual("C - Carrot", my_bundle.files.@"C.txt".bytes(data));
    try expectEqual("Nested asset\n", my_bundle.files.nested.@"nested.txt".bytes(data));
    try expectEqual("A - Apricot", other_bundle.files.@"A.txt".bytes(other_data));
    try expectEqual("B - Blueberry", other_bundle.files.@"B.txt".bytes(other_data));
    try expectEqual("C - Citrus", other_bundle.files.@"C.txt".bytes(other_data));
    if (my_bundle.size_extracted > data.len) return error.InvalidExtractedSize;
    if (other_bundle.size_extracted > other_data.len) return error.InvalidExtractedSize;

    std.debug.print(
        \\A: '{s}'
        \\B: '{s}'
        \\C: '{s}'
        \\N: '{s}'
        \\
        \\({}) ({})
        \\
        \\
    , .{
        my_bundle.files.@"A.txt".get(data),
        my_bundle.files.@"B.txt".get(data),
        my_bundle.files.@"C.txt".get(data),
        my_bundle.files.nested.@"nested.txt".get(data),
        my_bundle.size_compressed,
        my_bundle.size_extracted,
    });

    std.debug.print(
        \\A: '{s}'
        \\B: '{s}'
        \\C: '{s}'
        \\
        \\({}) ({})
        \\
        \\
    , .{
        other_bundle.files.@"A.txt".get(other_data),
        other_bundle.files.@"B.txt".get(other_data),
        other_bundle.files.@"C.txt".get(other_data),
        other_bundle.size_compressed,
        other_bundle.size_extracted,
    });
}

fn expectEqual(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.InvalidBundleContent;
}
