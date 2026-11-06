const std = @import("std");
const frostbyte = @import("frostbyte");
const MAX_PAYLOAD = frostbyte.protocol.DEFAULT_MAX_PAYLOAD;

fn handleFrame(allocator: std.mem.Allocator, reader: anytype, writer: anytype, header: *const [frostbyte.protocol.HEADER_LEN]u8) !void {
    const payload_len = std.mem.readInt(u32, header[8..12], .big);
    if (payload_len > MAX_PAYLOAD) return error.PayloadTooLarge;
    const total_len = frostbyte.protocol.HEADER_LEN + @as(usize, payload_len);
    const packet = try allocator.alloc(u8, total_len);
    defer allocator.free(packet);
    @memcpy(packet[0..frostbyte.protocol.HEADER_LEN], header);
    try reader.readNoEof(packet[frostbyte.protocol.HEADER_LEN..]);
    const frame = try frostbyte.decode(packet, MAX_PAYLOAD);
    const response = try frostbyte.encode(allocator, frame.header.message_type, frame.header.flags, frame.payload);
    defer allocator.free(response);
    try writer.writeAll(response);
}

fn serveConnection(stream: std.net.Stream) !void {
    defer stream.close();
    const reader = stream.reader();
    const writer = stream.writer();
    const allocator = std.heap.page_allocator;
    while (true) {
        var header: [frostbyte.protocol.HEADER_LEN]u8 = undefined;
        reader.readNoEof(&header) catch |err| {
            if (err == error.EndOfStream) return;
            return err;
        };
        try handleFrame(allocator, reader, writer, &header);
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const port: u16 = if (args.len > 1) try std.fmt.parseInt(u16, args[1], 10) else 9000;
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();
    std.log.info("FROSTBYTE framed TCP echo server listening on port {d}", .{port});
    while (true) {
        const connection = try server.accept();
        serveConnection(connection.stream) catch |err|
            std.log.warn("connection closed: {s}", .{@errorName(err)});
    }
}
