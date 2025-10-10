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

    fn u32ToIp(addr: u32) std.net.Ip4Address {
        return std.net.Ip4Address.init([4]u8{
            @truncate(addr >> 24),
            @truncate(addr >> 16),
            @truncate(addr >> 8),
            @truncate(addr),
        }, 0);
    }
};

fn testIp(octets: [4]u8) u32 {
    return (@as(u32, octets[0]) << 24) |
        (@as(u32, octets[1]) << 16) |
        (@as(u32, octets[2]) << 8) |
        @as(u32, octets[3]);
}

test "init masks host bits to get network address" {
    const expected = std.net.Ip4Address.init(.{ 192, 168, 1, 0 }, 0);
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);

    try std.testing.expectEqual(expected, subnet.networkAddress());
    try std.testing.expectEqual(@as(u5, 28), subnet.prefix_len);
}

test "netmask returns IP address" {
    const expected = std.net.Ip4Address.init(.{ 255, 255, 255, 240 }, 0);
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);

    try std.testing.expectEqual(expected, subnet.netmask());
}
