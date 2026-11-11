const std = @import("std");
const Io = std.Io;

pub fn printTest(writer: *Io.Writer, msg: []const u8) Io.Writer.Error!void {
    try writer.writeAll(msg);
}

test "printTest writes hi" {
    var buffer: [32]u8 = undefined;
    var writer: Io.Writer = .fixed(&buffer);

    try printTest(&writer, "hi");

    try std.testing.expect(
        std.mem.eql(u8, writer.buffered(), "hi"),
    );
}
