const std = @import("std");
const console = @import("console");
const Compiler = @import("Compiler");

pub fn main() !void {
    try console.init();
    defer console.deinit();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};

    var temp = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var c = Compiler.init(gpa.allocator(), arena.allocator());

    var arg_iter = try std.process.ArgIterator.initWithAllocator(temp.allocator());
    _ = arg_iter.next(); // ignore command name
    while (arg_iter.next()) |arg| {
        c.addFile(std.fs.cwd(), arg);
    }
    temp.deinit();

    c.start();
    c.finish();

    try c.printErrors(std.io.getStdErr().writer());
}
