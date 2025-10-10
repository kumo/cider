//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const Subnet = struct {
    network: u32,
    prefix_len: u5,

    pub fn init(ip: u32, prefix_len: u5) Subnet {
        // Get the network address from the IP and netmask
        const network = ip & calculateNetmask(prefix_len);

        return .{
            .network = network,
            .prefix_len = prefix_len,
        };
    }

    pub fn parse(cidr: []const u8) !Subnet {
        var iter = std.mem.splitScalar(u8, cidr, '/');

        const ip_str = iter.next() orelse return error.InvalidCidr;
        const prefix_str = iter.next() orelse return error.InvalidCidr;

        // Ensure there are no extra slashes
        if (iter.next() != null) return error.InvalidCidr;

        const ip = std.net.Ip4Address.parse(ip_str, 0) catch return error.InvalidCidr;
        const prefix_len = std.fmt.parseInt(u5, prefix_str, 10) catch return error.InvalidCidr;

        return Subnet.init(ip.sa.addr, prefix_len);
    }

    pub fn firstIpAddress(self: Subnet) std.net.Ip4Address {
        return u32ToIp(self.network + 1);
    }

    pub fn lastIpAddress(self: Subnet) std.net.Ip4Address {
        return u32ToIp(self.network + self.ipCount());
    }

    pub fn ipCount(self: Subnet) u32 {
        return calculateTotalIps(self.prefix_len) - 2;
    }

    pub fn netmask(self: Subnet) std.net.Ip4Address {
        return u32ToIp(calculateNetmask(self.prefix_len));
    }

    pub fn networkAddress(self: Subnet) std.net.Ip4Address {
        return u32ToIp(self.network);
    }

    // --- Private helpers

    fn calculateNetmask(prefix_len: u5) u32 {
        const shift: u5 = @intCast(32 - @as(u6, prefix_len));
        return ~@as(u32, 0) << shift;
    }

    fn calculateTotalIps(prefix_len: u5) u32 {
        const shift: u5 = @intCast(32 - @as(u6, prefix_len));
        return @as(u32, 1) << shift;
    }

    fn u32ToIp(addr: u32) std.net.Ip4Address {
        return std.net.Ip4Address.init([4]u8{
            @truncate(addr >> 24),
            @truncate(addr >> 16),
            @truncate(addr >> 8),
            @truncate(addr),
        }, 0);
    }
};

// Test helper to create IP address as u32
fn testIp(octets: [4]u8) u32 {
    return (@as(u32, octets[0]) << 24) |
        (@as(u32, octets[1]) << 16) |
        (@as(u32, octets[2]) << 8) |
        @as(u32, octets[3]);
}

test "init masks host bits to get network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);
    const expected = std.net.Ip4Address.init(.{ 192, 168, 1, 0 }, 0);

    try std.testing.expectEqual(expected, subnet.networkAddress());
    try std.testing.expectEqual(@as(u5, 28), subnet.prefix_len);
}

test "parse returns errors for invalid CIDRs" {
    // Missing slash
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1.0"));

    // Invalid prefix
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1.0/abc"));

    // Multiple prefix
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1.0/1/2/3"));

    // Empty prefix
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1.0/"));

    // Overflowing prefix
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1.0/9999"));

    // Invalid IP
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("192.168.1/28"));

    // No data
    try std.testing.expectError(error.InvalidCidr, Subnet.parse(""));

    // Text
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("localhost"));

    // Emoji
    try std.testing.expectError(error.InvalidCidr, Subnet.parse("🏪📦⚠️"));
}

test "firstIpAddress returns IP after network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 0 }), 28);
    const expected = std.net.Ip4Address.init(.{ 192, 168, 1, 1 }, 0);

    try std.testing.expectEqual(expected, subnet.firstIpAddress());
}

test "lastIpAddress returns 'ipCount' IPs after network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 0 }), 28);
    const expected = std.net.Ip4Address.init(.{ 192, 168, 1, 14 }, 0);

    try std.testing.expectEqual(14, subnet.ipCount());
    try std.testing.expectEqual(expected, subnet.lastIpAddress());
}

test "ipCount calculates based on prefix " {
    // 28
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);

        try std.testing.expectEqual(14, subnet.ipCount());
    }

    // 29
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 29);

        try std.testing.expectEqual(6, subnet.ipCount());
    }

    // 25
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 25);

        try std.testing.expectEqual(126, subnet.ipCount());
    }
}

test "netmask calculates based on prefix" {
    // 28
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);
        const expected = std.net.Ip4Address.init(.{ 255, 255, 255, 240 }, 0);

        try std.testing.expectEqual(expected, subnet.netmask());
    }

    // 29
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 29);
        const expected = std.net.Ip4Address.init(.{ 255, 255, 255, 248 }, 0);

        try std.testing.expectEqual(expected, subnet.netmask());
    }

    // 25
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 25);
        const expected = std.net.Ip4Address.init(.{ 255, 255, 255, 128 }, 0);

        try std.testing.expectEqual(expected, subnet.netmask());
    }
}
