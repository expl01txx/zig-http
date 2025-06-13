const std = @import("std");

pub const HttpServer = struct {
    alloc: std.mem.Allocator,
    routes: std.StringHashMap(*const fn () []const u8),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{ .alloc = allocator, .routes = std.StringHashMap(*const fn () []const u8).init(allocator) };
    }

    pub fn addRoute(self: *@This(), route: []const u8, handler: *const fn () []const u8) !void {
        try self.routes.put(route, handler);
    }

    pub fn serve(self: *@This(), ip: []const u8, port: u16) !void {
        const address = try std.net.Address.parseIp(ip, port);

        const tpe = std.posix.SOCK.STREAM;
        const protocol = std.posix.IPPROTO.TCP;

        const listener = try std.posix.socket(address.any.family, tpe, protocol);
        defer std.posix.close(listener);

        try std.posix.setsockopt(listener, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try std.posix.bind(listener, &address.any, address.getOsSockLen());
        try std.posix.listen(listener, 128);

        std.debug.print("Listening from: {s}:{}\n", .{ ip, port });

        while (true) {
            var client_address: std.net.Address = undefined;
            var client_address_len: std.posix.socklen_t = @sizeOf(std.net.Address);

            const socket = std.posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
                std.debug.print("Failed to accept: {}\n", .{err});
                continue;
            };
            defer std.posix.close(socket);
            std.debug.print("Connected: {}\n", .{client_address});

            var buf: [1024]u8 = undefined;

            const read = std.posix.read(socket, &buf) catch |err| {
                std.debug.print("Failed to read data: {}\n", .{err});
                continue;
            };

            if (read == 0) {
                continue;
            }

            const route = try self.parseRoute(&buf);

            const handler = self.routes.get(route);

            if (handler == null) {
                const error_payload =
                    \\HTTP/1.1 200 OK
                    \\Content-Type: text/html; charset=utf-8
                    \\Connection: keep-alive
                    \\
                    \\<!doctype html><h1>Page not found!</h1>
                ;
                write(socket, error_payload) catch |err| {
                    std.debug.print("Failed to send data: {}\n", .{err});
                };
                continue;
            }

            const payload =
                \\HTTP/1.1 200 OK
                \\Content-Type: text/html; charset=utf-8
                \\Connection: keep-alive
                \\
                \\
            ;

            const response = handler.?();

            try write(socket, payload);
            try write(socket, response);
        }
    }

    pub fn parseRoute(_: *@This(), request_line: []const u8) ![]const u8 {
        var iter = std.mem.splitAny(u8, request_line, " ");

        _ = iter.next() orelse return error.InvalidRequest;

        const route = iter.next() orelse return error.InvalidRequest;

        return route;
    }

    pub fn deinit(self: *@This()) !void {
        try self.routes.deinit();
    }
};

fn write(socket: std.posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try std.posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
