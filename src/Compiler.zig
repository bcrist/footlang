const std = @import("std");
const console = @import("console");
const Token = @import("Token.zig");
const Parser = @import("Parser.zig");
const Source = @import("Source.zig");
const Error = @import("Error.zig");

const Compiler = @This();

gpa: std.mem.Allocator,
arena: std.mem.Allocator,
sources: std.ArrayListUnmanaged(Source) = .{},
errors: std.ArrayListUnmanaged(Error) = .{},

pub fn init(gpa: std.mem.Allocator, arena: std.mem.Allocator) Compiler {
    // It's possible to use the same allocator for gpa and arena,
    // but nothing allocated in the arena allocator will be freed
    // until Compiler.deinit() is called, so it's a good candidate
    // for std.heap.ArenaAllocator use.

    var self = Compiler{
        .gpa = gpa,
        .arena = arena,
    };

    return self;
}

pub fn deinit(self: *Compiler, deinit_arena: bool) void {
    var maybe_arena = if (deinit_arena) self.arena else null;

    for (self.sources.items) |source| {
        source.deinit(self.gpa, maybe_arena);
    }

    for (self.errors.items) |err| {
        if (err.flags.contains(.desc_is_allocated_from_arena)) {
            self.arena.free(err.desc);
        }
    }

    self.sources.deinit(self.gpa);
    self.errors.deinit(self.gpa);
}

pub fn addFile(self: *Compiler, dir: std.fs.Dir, path: []const u8) void {
    const text = dir.readFileAlloc(self.arena, path, 1024*1024*1024) catch |err| {
        std.debug.print("Failed to read source file: {s}: {s}", .{ path, @errorName(err) });
        return;
    };
    const name = self.arena.dupe(u8, path) catch @panic("OOM");
    self.adoptSource(name, text);
}

pub fn addSource(self: *Compiler, name: []const u8, text: []const u8) void {
    const owned_name = self.arena.dupe(name) catch @panic("OOM");
    const owned_text = self.arena.dupe(text) catch @panic("OOM");
    self.adoptSource(owned_name, owned_text);
}

pub var debug_text: []const u8 = "";
pub var debug_token_offsets: []const u32 = &.{};

// Takes ownership of name and source; assumed to have been allocated with self.arena
pub fn adoptSource(self: *Compiler, name: []const u8, text: []const u8) void {
    const handle = @intCast(Source.Handle, self.sources.items.len);
    const tokens = Token.lex(self.gpa, text);

    debug_text = text;
    debug_token_offsets = tokens.items(.offset);

    var parser = Parser.init(self.gpa, self.gpa);

    parser.parse(handle, tokens.items(.kind));

    parser.dump(.{
        .source_text = text,
        .token_offsets = tokens.items(.offset),
        .styles = &.{
            .{ .fg = .blue },
            .{},
            .{ .fg = .cyan },
            .{ .fg = .green },
            .{ .fg = .yellow },
            .{ .fg = .red },
            .{ .fg = .magenta },
        },
    }, std.io.getStdOut().writer()) catch {};

    self.errors.appendSlice(self.gpa, parser.errors.items) catch @panic("OOM");
    parser.errors.clearRetainingCapacity();

    self.sources.append(self.gpa, .{
        .handle = handle,
        .name = name,
        .text = text,
        .token_data = tokens,
    }) catch @panic("OOM");
}

pub fn start(self: *Compiler) void {
    _ = self;
}

pub fn finish(self: *Compiler) void {
    _ = self;
}

pub fn printErrors(self: *Compiler, writer: anytype) !void {
    var i: Error.Handle = 0;
    while (i < self.errors.items.len) {
        i = try Error.print(self, i, writer);
    }
}

pub fn recordError(self: *Compiler, source_handle: Source.Handle, context: Error.Context, desc: []const u8, flags: Error.FlagSet) void {
    self.errors.append(self.gpa, .{
        .file = source_handle,
        .context = context,
        .desc = desc,
        .flags = flags,
    }) catch @panic("OOM");
}

pub fn recordErrorFmt(self: *Compiler, source_handle: Source.Handle, context: Error.Context, comptime fmt: []const u8, args: anytype, flags: Error.FlagSet) void {
    const desc = std.fmt.allocPrint(self.arena, fmt, args) catch @panic("OOM");
    var mutable_flags = flags;
    mutable_flags.insert(.desc_is_allocated_from_arena);
    self.recordError(source_handle, context, desc, mutable_flags);
}

pub fn recordTokenError(self: *Compiler, source_handle: Source.Handle, token: Token.Handle, desc: []const u8, flags: Error.FlagSet) void {
    recordError(self, source_handle, .{ .token = token }, desc, flags);
}

pub fn recordTokenErrorFmt(self: *Compiler, source_handle: Source.Handle, token: Token.Handle, comptime fmt: []const u8, args: anytype, flags: Error.FlagSet) void {
    recordErrorFmt(self, source_handle, .{ .token = token }, fmt, args, flags);
}
