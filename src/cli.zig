const std = @import("std");

pub const Config = struct {
    cidr: []const u8,
    calculate_next: bool = false,

    pub fn fromArgs(allocator: std.mem.Allocator, args: []const []const u8) !Config {
        if (args.len < 2) {
            return error.MissingCIDR;
        }

        if (args.len == 2) {
            return Config{
                .cidr = try allocator.dupe(u8, args[1]),
                .calculate_next = false,
            };
        }

        if (args.len == 3 and std.mem.eql(u8, args[1], "next")) {
            return Config{
                .cidr = try allocator.dupe(u8, args[2]),
                .calculate_next = true,
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

    try std.testing.expectError(error.InvalidArgCount, config);
}

test "Parse valid CIDR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "192.168.1.0/24" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(false, config.calculate_next);
}

test "Parse multiple args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "192.168.1.0", "/", "24" };
    const config = Config.fromArgs(allocator, &args);

    try std.testing.expectError(error.InvalidArgCount, config);
}

test "Parse with 'next' command" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "next", "192.168.1.0/24" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(true, config.calculate_next);
}
