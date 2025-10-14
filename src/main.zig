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

    const config = Config.fromArgs(allocator, args) catch {
        std.debug.print("Usage:\n", .{});
        std.debug.print("  cider <cidr>        Show CIDR info\n", .{});
        std.debug.print("  cider next <cidr>   Calculate next subnet\n", .{});
        std.debug.print("\nExample:\n", .{});
        std.debug.print("  cider 192.168.1.0/24\n", .{});
        std.debug.print("  cider next 192.168.1.0/24\n", .{});
        return;
    };
    const subnet = Subnet.parse(config.cidr) catch {
        std.debug.print("Invalid CIDR format. Expected format: ip/prefix (e.g., 192.168.1.0/24)\n", .{});
        return;
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (config.calculate_next) {
        try stdout.print("{f}", .{subnet.next()});
    } else {
        try stdout.print("{f}", .{subnet});
    }

    try stdout.flush();
}
