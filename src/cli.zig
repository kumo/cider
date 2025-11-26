const std = @import("std");

pub const Command = enum {
    info,
    next,
    transform,
};

pub const Config = struct {
    cidr: []const u8,
    command: Command = .info,
    new_prefix_len: ?u5 = null,
    allow_backwards: bool = false,

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

        // Parse command (next or transform)
        const command_str = args[1];
        const command = if (std.mem.eql(u8, command_str, "next"))
            Command.next
        else if (std.mem.eql(u8, command_str, "transform"))
            Command.transform
        else
            return error.InvalidArguments;

        if (args.len < 3) {
            return error.MissingCIDR;
        }

        const cidr = args[2];
        var new_prefix_len: ?u5 = null;
        var allow_backwards = false;

        // Parse optional flags
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--subnet")) {
                if (i + 1 >= args.len) {
                    return error.InvalidArguments;
                }
                i += 1;

                var prefix_str = args[i];
                if (prefix_str.len > 0 and prefix_str[0] == '/') {
                    prefix_str = prefix_str[1..];
                }

                new_prefix_len = std.fmt.parseInt(u5, prefix_str, 10) catch return error.InvalidArguments;
            } else if (std.mem.eql(u8, arg, "--allow-backwards")) {
                allow_backwards = true;
            } else {
                return error.InvalidArguments;
            }
        }

        // Validate: transform requires --subnet
        if (command == .transform and new_prefix_len == null) {
            return error.InvalidArguments;
        }

        return Config{
            .cidr = try allocator.dupe(u8, cidr),
            .command = command,
            .new_prefix_len = new_prefix_len,
            .allow_backwards = allow_backwards,
        };
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

test "Parse with 'next' command without --subnet uses same prefix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "next", "192.168.1.0/24" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.next, config.command);
    try std.testing.expectEqual(@as(?u5, null), config.new_prefix_len);
}

test "Parse next with --subnet flag (numeric)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "next", "192.168.1.0/24", "--subnet", "27" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.next, config.command);
    try std.testing.expectEqual(@as(u5, 27), config.new_prefix_len.?);
}

test "Parse next with --subnet flag (with slash)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "next", "192.168.1.0/24", "--subnet", "/27" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.next, config.command);
    try std.testing.expectEqual(@as(u5, 27), config.new_prefix_len.?);
}

test "Parse transform command" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "transform", "192.168.1.0/24", "--subnet", "27" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.transform, config.command);
    try std.testing.expectEqual(@as(u5, 27), config.new_prefix_len.?);
    try std.testing.expectEqual(false, config.allow_backwards);
}

test "Parse transform with --allow-backwards flag" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "transform", "192.168.1.0/24", "--subnet", "27", "--allow-backwards" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.transform, config.command);
    try std.testing.expectEqual(@as(u5, 27), config.new_prefix_len.?);
    try std.testing.expectEqual(true, config.allow_backwards);
}

test "Parse transform with --allow-backwards before --subnet" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = [_][]const u8{ "cider", "transform", "192.168.1.0/24", "--allow-backwards", "--subnet", "27" };
    const config = try Config.fromArgs(allocator, &args);

    try std.testing.expectEqualStrings("192.168.1.0/24", config.cidr);
    try std.testing.expectEqual(.transform, config.command);
    try std.testing.expectEqual(@as(u5, 27), config.new_prefix_len.?);
    try std.testing.expectEqual(true, config.allow_backwards);
}
