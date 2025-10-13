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

    std.debug.print("Network: {s}, Mask: {s}\n", .{ subnet.networkAddress(), subnet.netmask() });
}
