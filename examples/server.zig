const std = @import("std");
const zintake = @import("zintake");

pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    const rout = zintake.r.Router.init(server_allocator);

    var s = zintake.Server.init(address, server_allocator, rout);
    // want to see something very stupid, change this to const below
    var endpointGroup = [_]zintake.endpoint.Endpoint{
        zintake.endpoint.Endpoint.new(zintake.endpoint.method.GET, "/hello", handleMe),
        zintake.endpoint.Endpoint.new(zintake.endpoint.method.GET, "/api/hello", handleMe),
    };
    try s.addRoutes(endpointGroup[0..]);
    try s.run(); // this block
}

const person = struct {
    name: []const u8,
    addr: []const u8,
};

fn handleMe(conn: *std.http.Server.Response) void {
    var buf: [1024 * 1024]u8 = undefined;
    const n = conn.reader().readAll(&buf) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    _ = n;
    const payload = person{
        .name = "dean",
        .addr = "3591 hawfinch",
    };

    var fbuf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&fbuf);

    _ = std.json.stringify(payload, .{}, fbs.writer()) catch |err| {
        std.log.err("error stringify {any}", .{err});
        return;
    };

    conn.transfer_encoding = .{ .content_length = fbs.pos };

    _ = conn.writeAll(fbuf[0..fbs.pos]) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };
}
