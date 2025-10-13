//! By convention, root.zig is the root source file when making a library.
pub const Subnet = @import("subnet.zig").Subnet;

test {
    _ = @import("subnet.zig");
}
