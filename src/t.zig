pub const A = @import("endpoint.zig");
pub const B = @import("router.zig");
pub const zintake = @import("zintake.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
