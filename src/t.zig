pub const A = @import("endpoint.zig");
pub const B = @import("router.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
