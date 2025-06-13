const std = @import("std");
const lib = @import("ZHttp_lib");

fn index() []const u8 {
    return "<h1>Hello, World</h1>";
}

fn kasik() []const u8 {
    return "<h1>KASIK LOX!</h1>";
}

pub fn main() !void {
    var http_server = lib.HttpServer.init(std.heap.page_allocator);

    try http_server.addRoute("/", &index);
    try http_server.addRoute("/kasik", &kasik);

    try http_server.serve("0.0.0.0", 7777);
}
