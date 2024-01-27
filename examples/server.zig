const std = @import("std");
const r = @import("zintake");
pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    // _ = server_allocator;
    // std.debug.print("hello, {any}", .{r});

    const rout = r.r.Router.init(server_allocator);
    var s = r.Server.init(address, server_allocator, rout);
    try s.run(); // this block  s
}
