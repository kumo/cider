const std = @import("std");

pub const Config = struct {
    cidr: []const u8,

    pub fn fromArgs(allocator: std.mem.Allocator, args: []const []const u8) !Config {
        if (args.len != 2) {
            return error.InvalidArgCount;
        }

        return Config{
            .cidr = try allocator.dupe(u8, args[1]),
        };
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
}

test "Parse multiple args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "192.168.1.0", "/", "24" };
    const config = Config.fromArgs(allocator, &args);

    try std.testing.expectError(error.InvalidArgCount, config);
}
