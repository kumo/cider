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
        std.debug.print("  cider <cidr>                                  Show CIDR info\n", .{});
        std.debug.print("  cider next <cidr> [--subnet <prefix>]        Calculate next subnet\n", .{});
        std.debug.print("  cider transform <cidr> --subnet <prefix> [--allow-backwards]\n", .{});
        std.debug.print("                                                Resize to different prefix\n", .{});
        std.debug.print("\nExample:\n", .{});
        std.debug.print("  cider 192.168.1.0/24\n", .{});
        std.debug.print("  cider next 192.168.1.0/24\n", .{});
        std.debug.print("  cider next 192.168.1.0/24 --subnet 27\n", .{});
        std.debug.print("  cider transform 192.168.1.0/24 --subnet 27\n", .{});
        return;
    };
    const subnet = Subnet.parse(config.cidr) catch {
        std.debug.print("Invalid CIDR format. Expected format: ip/prefix (e.g., 192.168.1.0/24)\n", .{});
        return;
    };

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    switch (config.command) {
        .info => {
            try stdout.print("{f}", .{subnet});
        },
        .next => {
            const next_subnet = if (config.new_prefix_len) |prefix_len|
                try subnet.nextWithSize(prefix_len)
            else
                subnet.next();

            try stdout.print("{f}", .{next_subnet});

            // Detect and report gap
            if (subnet.hasGap(next_subnet)) {
                try stdout.print("\nGap detected between subnets\n", .{});
            }
        },
        .transform => {
            const new_prefix_len = config.new_prefix_len orelse return;
            const transformed = subnet.transform(new_prefix_len, config.allow_backwards) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                return;
            };

            try stdout.print("{f}", .{transformed});

            // Detect and report gap
            if (subnet.hasGap(transformed)) {
                try stdout.print("\nGap detected between subnets\n", .{});
            }
        },
    }

    try stdout.flush();
}
