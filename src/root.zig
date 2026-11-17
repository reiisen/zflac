const std = @import("std");
const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;


pub const BitReader = struct {
    slice: []const u8,
    pos: usize = 0,
    current: u64 = undefined,

    pub fn init(slice: []const u8) @This() {
        return @This(){ .slice = slice };
    }

    pub fn readBit(self: *@This(), pos: usize) !u1 {
        // using a lot of @truncate here because the need of
        // satisfying the compiler complaints of asserting u3's
        return if (pos < self.slice.len * 8)
            @truncate((self.slice[pos / 8] >> @as(u3, @truncate(7 - (pos % 8)))))
        else
            error.OutOfBounds;
    }

    pub fn readBits(self: *@This(), n: usize) !*@This() {
        var value: usize = 0;
        for (0..n) |i| {
            const bit = try self.readBit(self.pos + i);
            value <<= 1;
            value |= @as(usize, bit);
        }

        // if the reading above fails, the entire function fails
        // so then nothing gets modified...
        self.pos = self.pos + n;
        self.current = value;
        return self;
    }
};

test "BitReader Struct" {
    const value: u64 = 0xFF00AA00F0F000FF;
    var slice: [8]u8 = undefined;
    std.mem.writeInt(u64, &slice, value, .big);

    var bitReader = BitReader.init(&slice);

    try std.testing.expectError(error.OutOfBounds, bitReader.readBits(100));
    try std.testing.expectEqual(0, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0xFF), (try bitReader.readBits(8)).current);
    try std.testing.expectEqual(8, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0), (try bitReader.readBits(8)).current);
    try std.testing.expectEqual(16, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b10), (try bitReader.readBits(2)).current);
    try std.testing.expectEqual(18, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b101), (try bitReader.readBits(3)).current);
    try std.testing.expectEqual(21, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b010), (try bitReader.readBits(3)).current);
    try std.testing.expectEqual(24, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0x00F0F000FF), (try bitReader.readBits(40)).current);
    try std.testing.expectEqual(64, bitReader.pos);

    // inner readBit will fail cause out of bounds
    // therefore pos should not update and returned
    // with OutOfBounds
    try std.testing.expectError(error.OutOfBounds, bitReader.readBits(5));
    try std.testing.expectEqual(64, bitReader.pos);

    bitReader.pos = 0;
    try std.testing.expectEqual(value, (try bitReader.readBits(64)).current);
    try std.testing.expectEqual(64, bitReader.pos);
}

pub fn BitReaderC(comptime T: type) type {
    return struct {
        slice: T,
        pos: usize,
        current: T,

        pub fn init(slice: T) @This() {
            return .{ .slice = slice, .pos = 0, .current = 0 };
        }

        fn readBit(self: *@This(), pos: usize) !u1 {
            const size: usize = @bitSizeOf(T);
            if (pos < size) {
                const rhs: std.math.Log2Int(T) = @intCast(size - 1 - pos);
                return @truncate((self.slice >> rhs));
            }
            return error.OutOfBounds;
        }

        pub fn readBits(self: *@This(), n: usize) !*@This() {
            // return an error when it's obviously going to be oob
            if (n > @bitSizeOf(T)) return error.IncorrectValue;

            // i freakin hope they just cast this as T without any complaint
            var value: T = 0;
            for (0..n) |i| {
                const bit = try self.readBit(self.pos + i);
                value <<= 1;
                value |= @as(T, bit);
            }

            // if the reading above fails, the entire function fails
            // therefore nothing gets modified...
            self.pos = self.pos + n;

            self.current = value;
            return self;
        }
    };
}

test "BitReaderC Struct" {
    const value: u64 = 0xFF00AA00F0F000FF;
    var bitReader = BitReaderC(@TypeOf(value)).init(value);

    try std.testing.expectError(error.IncorrectValue, bitReader.readBits(100));
    try std.testing.expectEqual(0, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0xFF), (try bitReader.readBits(8)).current);
    try std.testing.expectEqual(8, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0), (try bitReader.readBits(8)).current);
    try std.testing.expectEqual(16, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b10), (try bitReader.readBits(2)).current);
    try std.testing.expectEqual(18, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b101), (try bitReader.readBits(3)).current);
    try std.testing.expectEqual(21, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b010), (try bitReader.readBits(3)).current);
    try std.testing.expectEqual(24, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0x00F0F000FF), (try bitReader.readBits(40)).current);
    try std.testing.expectEqual(64, bitReader.pos);

    // inner readBit will fail cause out of bounds
    // therefore pos should not update and returned
    // with OutOfBounds
    try std.testing.expectError(error.OutOfBounds, bitReader.readBits(5));
    try std.testing.expectEqual(64, bitReader.pos);

    bitReader.pos = 0;
    try std.testing.expectEqual(value, (try bitReader.readBits(64)).current);
    try std.testing.expectEqual(64, bitReader.pos);
}

pub fn toBits(slices: []const u8, allocator: std.mem.Allocator) ![]const u1 {
    // the slices might be big af so we push to heap temporarily
    const bits = try allocator.alloc(u1, (slices.len) * 8);

    for (0..slices.len) |slice| {
        for (0..8) |i| {
            bits[slice * 8 + i] = @truncate(slices[slice] >> @as(u3, @truncate(7 - i)));
        }
    }

    return bits;
}

test "toBits" {
    const val: u16 = 0b1100111100001010;
    var slices: [2]u8 = undefined;
    std.mem.writeInt(u16, &slices, val, .big);
    const res = try toBits(&slices, std.testing.allocator);
    defer std.testing.allocator.free(res);
    const expected: []const u1 = &.{
        1, 1, 0, 0,
        1, 1, 1, 1,
        0, 0, 0, 0,
        1, 0, 1, 0,
    };
    try std.testing.expectEqualSlices(u1, expected, res);
}

pub const FileStream = struct {
    buf: []u8,
    reader: File.Reader,

    pub fn init(path: []const u8, dir: Dir, io: Io, allocator: std.mem.Allocator) !FileStream {
        const buf = try allocator.alloc(u8, 4096);
        const rbuf = try allocator.alloc(u8, 4096);
        const file = try Io.Dir.openFile(dir, io, path, .{});
        return FileStream{ .buf = buf, .reader = file.reader(io, rbuf) };
    }

    pub fn next(self: *FileStream) !usize {
        return try self.reader.interface.readSliceShort(self.buf);
    }

    pub fn back() void {}

    pub fn seek() void {}

    pub fn free(self: *FileStream, io: Io, allocator: std.mem.Allocator) void {
        allocator.free(self.buf);
        allocator.free(self.reader.interface.buffer);
        self.reader.file.close(io);
    }
};

test "stream" {
    const path = "/home/bak/Projects/zig/0.17.1/zflac/src/test.flac";

    const dir = std.testing.tmpDir(.{}).dir;
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var stream: FileStream = try FileStream.init(path, dir, io, allocator);
    defer stream.free(io, allocator);

    const readBytes = try stream.next();
    try expectEqual(4096, readBytes);
    try expectEqual('f', stream.buf[0]);
    try expectEqual('L', stream.buf[1]);
    try expectEqual('a', stream.buf[2]);
    try expectEqual('C', stream.buf[3]);
}
