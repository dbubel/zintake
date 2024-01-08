const std = @import("std");

pub const middleware = struct {
    const Self = @This();
    const next: *const fn (inner_next: *middleware) void = null;
    pub fn f() void {
        // do something here
        // now call next
        next();
    }
};
 
pub fn main() !void {
    var a = middleware{
      .next =  
    }
}
