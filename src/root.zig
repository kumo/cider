//! By convention, root.zig is the root source file when making a library.
pub const Config = @import("cli.zig").Config;
pub const Subnet = @import("subnet.zig").Subnet;

test {
    _ = @import("cli.zig");
    _ = @import("subnet.zig");
}
