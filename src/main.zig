const std = @import("std");
const Io = std.Io;
const bundle_template = @embedFile("bundle.zig");

const max_file_size: usize = 64 * 1024 * 1024;
const max_bundle_size: usize = 256 * 1024 * 1024;

const Entry = struct {
    path: []u8,
    kind: std.Io.File.Kind,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 4) @panic("invalid arguments");

    const generated_file_path = args[1];
    const compressed_file_path = args[2];
    const root_dir_path = args[3];

    var src_buffer: Io.Writer.Allocating = .init(gpa);
    defer src_buffer.deinit();
    const w = &src_buffer.writer;

    const root_dir = Io.Dir.cwd().openDir(io, root_dir_path, .{ .iterate = true }) catch |err| {
        std.process.fatal("unable to open directory '{s}': {t}", .{ root_dir_path, err });
    };

    var walker = try root_dir.walk(arena);
    defer walker.deinit();

    var entries: std.ArrayList(Entry) = .empty;
    defer {
        for (entries.items) |entry| gpa.free(entry.path);
        entries.deinit(gpa);
    }
    while (try walker.next(io)) |entry| {
        switch (entry.kind) {
            .directory, .file => try entries.append(gpa, .{
                .path = try gpa.dupe(u8, entry.path),
                .kind = entry.kind,
            }),
            else => {},
        }
    }
    std.mem.sort(Entry, entries.items, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return std.mem.lessThan(u8, a.path, b.path);
        }
    }.lessThan);

    const generated_file = try Io.Dir.cwd().createFile(io, generated_file_path, .{ .truncate = true });
    var generated_file_buf: [4096]u8 = undefined;
    var generated_file_writer = generated_file.writer(io, &generated_file_buf);

    const compressed_file = try Io.Dir.cwd().createFile(io, compressed_file_path, .{ .truncate = true });
    var compressed_file_buf: [4096]u8 = undefined;
    var compressed_file_writer = compressed_file.writer(io, &compressed_file_buf);

    var compressor_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var compressor = try std.compress.flate.Compress.init(&compressed_file_writer.interface, &compressor_buffer, .raw, .default);

    try w.print(
        \\{s}
        \\
        \\pub const files = struct {{
    , .{bundle_template});

    var size: usize = 0;
    var last_depth: usize = 1;
    for (entries.items) |entry| {
        const depth = std.mem.countScalar(u8, entry.path, std.fs.path.sep) + 1;
        while (last_depth > depth) : (last_depth -= 1) {
            try w.writeAll("};\n");
        }

        try w.print("\npub const {f}", .{std.zig.fmtId(std.fs.path.basename(entry.path))});
        switch (entry.kind) {
            else => {},
            .directory => {
                try w.print(" = struct {{", .{});
                last_depth = depth + 1;
            },
            .file => {
                const file_bytes = root_dir.readFileAlloc(io, entry.path, gpa, .limited(max_file_size + 1)) catch |err| {
                    std.process.fatal(
                        "unable to read file '{s}' in '{s}': {t}",
                        .{ std.fs.path.basename(entry.path), entry.path, err },
                    );
                };
                defer gpa.free(file_bytes);
                if (file_bytes.len > max_file_size) {
                    std.process.fatal("asset '{s}' exceeds the 64 MiB file limit", .{entry.path});
                }
                if (size + file_bytes.len + 1 > max_bundle_size) {
                    std.process.fatal("asset bundle exceeds the 256 MiB extracted size limit", .{});
                }

                try compressor.writer.writeAll(file_bytes);
                try compressor.writer.writeByte(0);

                try w.print(
                    \\: @import("akane_embed").Loc = .{{ .start = {}, .end = {} }};
                , .{ size, size + file_bytes.len });

                size += file_bytes.len + 1;
            },
        }
    }

    while (last_depth > 1) : (last_depth -= 1) {
        try w.writeAll("};\n");
    }

    try compressor.finish();
    try compressed_file_writer.flush();
    try w.print(
        \\}};
        \\
        \\pub const size_compressed = {};
        \\pub const size_extracted = {};
        \\
    , .{
        compressed_file_writer.logicalPos(),
        size,
    });

    const src = try src_buffer.toOwnedSliceSentinel(0);
    defer gpa.free(src);
    const ast = try std.zig.Ast.parse(arena, src, .zig);
    if (ast.errors.len != 0) {
        std.debug.print("Generated Zig source contains error, this is a bug in akane-embed!\n", .{});

        var out = Io.File.stderr().writerStreaming(io, &.{});
        for (ast.errors) |err| {
            try ast.renderError(err, &out.interface);
            std.debug.print("\n", .{});
        }

        std.debug.print("Code:\n----{s}\n----\n\n", .{src});
    }

    try ast.render(arena, &generated_file_writer.interface, .{});
    try generated_file_writer.flush();
}
