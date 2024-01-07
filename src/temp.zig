const std = @import("std");

fn firstMiddleware(next: *const fn (u32) void) *const fn (u32) void {
    _ = next;
    std.debug.print("first\n", .{});
    const x = fn (u32) void{};
    _ = x;
}

fn secondMiddleware(next: *const fn (u32) void) *const fn (u32) void {
    std.debug.print("second\n", .{});
    return next;
}

fn final(next: u32) void {
    std.debug.print("final: {any}\n", .{next});
}

pub fn main() void {
    const finalHandler: *const fn (u32) void = &final;
    const x = firstMiddleware(secondMiddleware(finalHandler));
    x(7);
    // const j: middlewareFunc = firstMiddleware;
    // const h: handler = *const fn () void{};
    // j(h);
    // firstMiddleware(x(2));
    // const chain = [_]*const middlewareFunc{ &firstMiddleware, &secondMiddleware };
    // for (chain) |func| {
    //     std.debug.print("func {any}\n", .{func});
    // }
}
