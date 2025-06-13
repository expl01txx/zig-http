# Zig Http - Simple http server written in Zig

### For now its only works for linux (its an experimental project)
### Example usage:
```zig
fn index() []const u8 {
    return "<h1>Hello, World</h1>";
}

pub fn main() !void {
    var http_server = lib.HttpServer.init(std.heap.page_allocator);
    try http_server.addRoute("/", &index);
    try http_server.serve("0.0.0.0", 7777);
```
