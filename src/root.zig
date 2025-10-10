//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const Subnet = struct {
    network: u32,
    prefix_len: u5,

    pub fn init(ip: u32, prefix_len: u5) Subnet {
        const shift = 32 - @as(u6, prefix_len);
        const mask = ~@as(u32, 0) << @intCast(shift);

        return .{
            .network = ip & mask,
            .prefix_len = prefix_len,
        };
    }
};

fn testIp(octets: [4]u8) u32 {
    return (@as(u32, octets[0]) << 24) |
        (@as(u32, octets[1]) << 16) |
        (@as(u32, octets[2]) << 8) |
        @as(u32, octets[3]);
}

test "init masks host bits to get network address" {
    const subnet = Subnet.init(testIp(.{ 192, 168, 1, 2 }), 28);

    try std.testing.expectEqual(testIp(.{ 192, 168, 1, 0 }), subnet.network);
    try std.testing.expectEqual(@as(u5, 28), subnet.prefix_len);
}
