const std = @import("std");
const zintake = @import("zintake");
const Endpoint = @import("zintake").endpoint.Endpoint;
const methods = std.http.Method;

pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    const rout = zintake.r.Router.init(server_allocator);

    var s = zintake.Server.init(address, server_allocator, rout);
    // want to see something very stupid, change this to const below instead of var
    var endpointGroup = [_]Endpoint{
        Endpoint.new(methods.GET, "/hello", handleMe),
        Endpoint.new(methods.GET, "/api/hello", handleMe),
    };
    try s.addRoutes(endpointGroup[0..]);
    try s.run(); // this blocks
}

const person = struct {
    name: []const u8,
    addr: []const u8,
};

const payload: person = person{
    .name = "dean",
    .addr = "3234 mars",
};

var handleAlloc = std.heap.GeneralPurposeAllocator(.{}){};
const handleAl = handleAlloc.allocator();
// const worker_allocator = handleAl.allocator();
// const allocator = arena.allocator();

// var arena = std.heap.ArenaAllocator.init(worker_allocator);

// _ = router;
// _ = router;
fn handleMe(conn: *std.http.Server.Response) void {

    // read the request made
    var buf: [1024 * 1024]u8 = undefined;
    const n: usize = conn.reader().readAll(&buf) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    // _ = n; // length of the request

    const p = std.json.parseFromSlice(person, handleAl, buf[0..n], .{}) catch |err| {
        conn.status = .bad_request;
        conn.transfer_encoding = .{ .content_length = 0 };

        conn.send() catch |erra| {
            std.log.err("error send {any}", .{erra});
        };
        std.log.err("json parse {any}", .{err});
        return;
    };
    defer p.deinit();

    zintake.RespondJSON(conn, .ok, p.value);
    conn.finish() catch |err| {
        std.log.err("error finish{any}", .{err});
        return;
    };
}
