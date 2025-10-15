const std = @import("std");

pub const Subnet = struct {
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

        const ip_addr = std.net.Ip4Address.parse(ip_str, 0) catch return error.InvalidCidr;
        const prefix_len = std.fmt.parseInt(u5, prefix_str, 10) catch return error.InvalidCidr;

        const ip = std.mem.bigToNative(u32, ip_addr.sa.addr);

        return Subnet.init(ip, prefix_len);
    }

    pub fn firstIp(self: Subnet) u32 {
        return self.network + 1;
    }

    pub fn lastIp(self: Subnet) u32 {
        return self.network + self.ipCount();
    }

    pub fn netmask(self: Subnet) u32 {
        return calculateNetmask(self.prefix_len);
    }

    pub fn ipCount(self: Subnet) u32 {
        return calculateTotalIps(self.prefix_len) - 2;
    }

    pub fn next(self: Subnet) Subnet {
        return Subnet.init(
            self.network + calculateTotalIps(self.prefix_len) + 2,
            self.prefix_len,
        );
    }

    pub fn format(this: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print(
            \\Network:   {f}
            \\Netmask:   {f}
            \\First IP:  {f}
            \\Last IP:   {f}
            \\CIDR:      /{d}
            \\Num Hosts: {d}
            \\
        , .{
            formatIp(this.network),
            formatIp(this.netmask()),
            formatIp(this.firstIp()),
            formatIp(this.lastIp()),
            this.prefix_len,
            this.ipCount(),
        });
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
};

fn formatIp(addr: u32) IpFormatter {
    return .{ .addr = addr };
}

const IpFormatter = struct {
    addr: u32, // Native byte order

    pub fn format(this: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{d}.{d}.{d}.{d}", .{
            (this.addr >> 24) & 0xFF,
            (this.addr >> 16) & 0xFF,
            (this.addr >> 8) & 0xFF,
            this.addr & 0xFF,
        });
    }
};

// Test helper to create IP address as u32
fn testIp(octets: [4]u8) u32 {
    return (@as(u32, octets[0]) << 24) |
        (@as(u32, octets[1]) << 16) |
        (@as(u32, octets[2]) << 8) |
        @as(u32, octets[3]);
}

fn expectEqualIp(expected: u32, actual: u32) !void {
    if (expected == actual) return;

    std.debug.print("\n" ++
        "Expected IP: {f}\n" ++
        "Actual IP:   {f}\n", .{
        formatIp(expected),
        formatIp(actual),
    });

    return error.TestExpectedEqual;
}

test "init masks host bits to get network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);
    const expected = testIp(.{ 192, 168, 1, 0 });

    try expectEqualIp(expected, subnet.network);
    try std.testing.expectEqual(@as(u5, 28), subnet.prefix_len);
}

test "parse creates valid subnet" {
    const subnet = try Subnet.parse("192.168.1.2/28");

    {
        const expected = testIp(.{ 192, 168, 1, 0 });

        try expectEqualIp(expected, subnet.network);
        try std.testing.expectEqual(@as(u5, 28), subnet.prefix_len);
    }

    {
        const expected = testIp(.{ 192, 168, 1, 1 });

        try expectEqualIp(expected, subnet.firstIp());
    }

    {
        const expected = testIp(.{ 192, 168, 1, 14 });

        try expectEqualIp(expected, subnet.lastIp());
    }
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
    const expected = testIp(.{ 192, 168, 1, 1 });

    try expectEqualIp(expected, subnet.firstIp());
}

test "lastIpAddress returns 'ipCount' IPs after network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 0 }), 28);
    const expected = testIp(.{ 192, 168, 1, 14 });

    try std.testing.expectEqual(14, subnet.ipCount());
    try expectEqualIp(expected, subnet.lastIp());
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
        const expected = testIp(.{ 255, 255, 255, 240 });

        try expectEqualIp(expected, subnet.netmask());
    }

    // 29
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 29);
        const expected = testIp(.{ 255, 255, 255, 248 });

        try expectEqualIp(expected, subnet.netmask());
    }

    // 25
    {
        const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 25);
        const expected = testIp(.{ 255, 255, 255, 128 });

        try expectEqualIp(expected, subnet.netmask());
    }
}

test "next returns the next subnet with the same size" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);
    const next_subnet = subnet.next();
    const expected = testIp(.{ 192, 168, 1, 16 });

    try expectEqualIp(expected, next_subnet.network);
    try expectEqualIp(subnet.prefix_len, next_subnet.prefix_len);
}
