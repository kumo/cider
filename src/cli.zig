const std = @import("std");

pub const Command = enum {
    info,
    next,
};

pub const Config = struct {
    cidr: []const u8,
    command: Command = .info,

    pub fn fromArgs(allocator: std.mem.Allocator, args: []const []const u8) !Config {
        if (args.len < 2) {
            return error.MissingCIDR;
        }

        if (args.len == 2) {
            return Config{
                .cidr = try allocator.dupe(u8, args[1]),
                .command = .info,
            };
        }

        if (args.len == 3 and std.mem.eql(u8, args[1], "next")) {
            return Config{
                .cidr = try allocator.dupe(u8, args[2]),
                .command = .next,
            };
        }

        return error.InvalidArguments;
    }
};

test "Parse missing args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{"cider"};
    const config = Config.fromArgs(allocator, &args);

    try std.testing.expectError(error.MissingCIDR, config);
}

test "Parse valid CIDR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "192.168.1.0/24" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.info, config.command);
}

test "Parse multiple args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "192.168.1.0", "/", "24" };
    const config = Config.fromArgs(allocator, &args);

    try std.testing.expectError(error.InvalidArguments, config);
}

test "Parse with 'next' command" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "next", "192.168.1.0/24" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.next, config.command);
}
