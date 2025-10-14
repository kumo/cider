const std = @import("std");
const Config = @import("cli.zig").Config;
const Subnet = @import("subnet.zig").Subnet;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    const config = try Config.fromArgs(allocator, args);
    const subnet = try Subnet.parse(config.cidr);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("{f}", .{subnet});
    try stdout.flush();
}
