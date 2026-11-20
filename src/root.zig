const std = @import("std");
const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
const testFile: []const u8 = "/home/bak/Projects/zig/0.17.1/zflac/src/test.flac"; 

fn printStruct(out: *std.Io.Writer, value: anytype) !void {
    const T = @TypeOf(value);
    const info = @typeInfo(T).@"struct";
    try out.print("{s} {{\n", .{@typeName(T)});
    // Names and types are parallel arrays, with a guaranteed equal length.
    // (Before, they were one `fields` array of structs. Zig removed that shape.)
    inline for (info.field_names, info.field_types) |name, Field| {
        const v = @field(value, name);
        // Strings need {s}. All other types get a usable default from {any}.
        // The branch is comptime. Thus the compiler compiles only one side for
        // each field.
        if (comptime Field == []const u8) {
            try out.print("  {s}: \"{s}\"\n", .{ name, v });
        } else {
            try out.print("  {s}: {any}\n", .{ name, v });
        }
    }
    try out.print("}}\n", .{});
}

pub const BitReader = struct {
    slice: []const u8,
    pos: usize = 0,
    current: usize = undefined,

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

    pub fn readBitF(self: *@This(), pos: usize) u1 {
        // TODO: Implement bounds-unchecked reading 
        self; pos;
        return 0;
    }

    pub fn readBits(self: *@This(), n: usize) !void {
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
        return;
    }

    pub fn readBitsF(self: *@This(), n: usize) void {
        // TODO: Implement bounds-unchecked reading
        self;
        n;
    }

    pub fn readBitsR(self: *@This(), n: usize) !*@This() {
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

    pub fn readBitsFR(self: *@This(), n: usize) !*@This() {
        // TODO: Implement bounds-unchecked reading
        self;
        n;
    }
};

test "BitReader Struct" {
    const value: u64 = 0xFF00AA00F0F000FF;
    var slice: [8]u8 = undefined;
    std.mem.writeInt(u64, &slice, value, .big);

    var bitReader = BitReader.init(&slice);

    try std.testing.expectError(error.OutOfBounds, bitReader.readBitsR(100));
    try std.testing.expectEqual(0, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0xFF), (try bitReader.readBitsR(8)).current);
    try std.testing.expectEqual(8, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0), (try bitReader.readBitsR(8)).current);
    try std.testing.expectEqual(16, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b10), (try bitReader.readBitsR(2)).current);
    try std.testing.expectEqual(18, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b101), (try bitReader.readBitsR(3)).current);
    try std.testing.expectEqual(21, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0b010), (try bitReader.readBitsR(3)).current);
    try std.testing.expectEqual(24, bitReader.pos);

    try std.testing.expectEqual(@as(@TypeOf(value), 0x00F0F000FF), (try bitReader.readBitsR(40)).current);
    try std.testing.expectEqual(64, bitReader.pos);

    // inner readBit will fail cause out of bounds
    // therefore pos should not update and returned
    // with OutOfBounds
    try std.testing.expectError(error.OutOfBounds, bitReader.readBitsR(5));
    try std.testing.expectEqual(64, bitReader.pos);

    bitReader.pos = 0;
    try std.testing.expectEqual(value, (try bitReader.readBitsR(64)).current);
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

        // honestly the return type is stupid because
        // u cant chain the method anyways since it
        // may return an error instead
        // is should be better to just return !void
        // to avoid "_ =" hassle
        //
        // or better yet just make a errorless bit reader
        // and frame the user for skill issue if it
        // doesnt work
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

pub const FileReader = struct {
    buf: []u8,
    reader: File.Reader,

    pub fn init(path: []const u8, dir: Dir, io: Io, size: usize, allocator: std.mem.Allocator) !FileReader {
        const buf = try allocator.alloc(u8, size);
        const rbuf = try allocator.alloc(u8, 1028);
        const file = try Io.Dir.openFile(dir, io, path, .{});
        return FileReader{ .buf = buf, .reader = file.reader(io, rbuf) };
    }

    pub fn next(self: *FileReader) !usize {
        return try self.reader.interface.readSliceShort(self.buf);
    }

    pub fn back() void {}

    pub fn seek() void {}

    pub fn free(self: *FileReader, io: Io, allocator: std.mem.Allocator) void {
        allocator.free(self.buf);
        allocator.free(self.reader.interface.buffer);
        self.reader.file.close(io);
    }
};

test "stream" {
    const path = testFile;

    const dir = std.testing.tmpDir(.{}).dir;
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var stream: FileReader = try FileReader.init(path, dir, io, 4096, allocator);
    defer stream.free(io, allocator);

    const readBytes = try stream.next();
    try expectEqual(4096, readBytes);
    try expectEqual('f', stream.buf[0]);
    try expectEqual('L', stream.buf[1]);
    try expectEqual('a', stream.buf[2]);
    try expectEqual('C', stream.buf[3]);
}

pub const MetadataBlock = enum(u7) {
    streaminfo,
    padding,
    application,
    seektable,
    vorbiscomment,
    cuesheet,
    picture,
    forbidden = 127,
    // other u7 values are marked as "reserved"
    _,
};

pub const MetadataFlag = enum(u1) {
    follow,
    last
};

pub const StreamInfo = struct {
    min_block_size: u16,
    max_block_size: u16,
    min_frame_size: u24,
    max_frame_size: u24,
    sample_rate: u20,
    channels: u3,
    bit_depth: u5,
    total_samples: u36,
    md5: u128
};

pub fn GetStreamInfo(bit_reader: *BitReader) !StreamInfo {
    // IN ORDER FOR THIS FUNCTION TO WORK, WE NEED THE BYTES
    // SPECIFICALLY, THE SIZE OF THE BLOCK SIZE DATA WE GOT
    // FROM THE HEADER
    // BUT I FEEL LIKE IT HAS DISCREPANCY...
    // STREAMINFO must be 34 bytes i think..
    
    // u know what, ima just use this function to control the bitreader

    var streaminfo: StreamInfo = undefined;
    // so we are in STREAMINFO
    // now we just need to parse each stream data
    
    // min block size
    try bit_reader.readBits(16); 
    streaminfo.min_block_size = @truncate(bit_reader.current);

    // max block size
    try bit_reader.readBits(16); 
    streaminfo.max_block_size = @truncate(bit_reader.current);

    // min frame size
    try bit_reader.readBits(24); 
    streaminfo.min_frame_size = @truncate(bit_reader.current);

    // max frame size
    try bit_reader.readBits(24); 
    streaminfo.max_frame_size = @truncate(bit_reader.current);

    // sample rate
    try bit_reader.readBits(20); 
    streaminfo.sample_rate = @truncate(bit_reader.current);

    // number of channels
    try bit_reader.readBits(3); 
    streaminfo.channels = @truncate(bit_reader.current);


    // bits per sample
    try bit_reader.readBits(5); 
    streaminfo.bit_depth = @truncate(bit_reader.current);

    // total samples
    try bit_reader.readBits(36); 
    streaminfo.total_samples = @truncate(bit_reader.current);

    // md5 checksum
    var actual: u128 = 0;
    const bitusize = @bitSizeOf(usize);
    for (0.. 128 / bitusize) |_| {
        try bit_reader.readBits(bitusize);  
        actual = actual << bitusize;
        actual = actual | bit_reader.current;
    }

    streaminfo.md5 = actual;

    return streaminfo;
}

test "walkthru" {
    const sign: []const u8 = "fLaC";
    const io = testing.io;
    const dir = std.testing.tmpDir(.{}).dir;
    const allocator = std.testing.allocator;
    
    // retreive bytes
    var reader: FileReader = try FileReader.init(testFile, dir, io, 1028, allocator);
    defer reader.free(io, allocator); 

    _ = try reader.next();
    
    // check sign
    var bitter = BitReader.init(reader.buf); 
    
    // check the 4 bytes
    for (0.. sign.len) |i| {
        try bitter.readBits(8);
        try expectEqual(sign[i], bitter.current);
    }

    // wow it fucking worked??

    // so now we read the METADATA block
    // first block must be a STREAMINFO
    // HEADER BLOCK is 4 bytes, first byte is type and last flag vvvvvvv 
    try bitter.readBits(1); 
    try expectEqual(@intFromEnum(MetadataFlag.follow), bitter.current);  

    try bitter.readBits(7); 
    try expectEqual(@intFromEnum(MetadataBlock.streaminfo), bitter.current);  

    // remaining 3 bytes is the size of the block excluding the 4 bytes header

    try bitter.readBits(24); 
    try expectEqual(0x000022, bitter.current);  

    const streaminfo: StreamInfo = try GetStreamInfo(&bitter);

    var w_buf: [1028]u8 = undefined;
    var writer = Io.File.writer(Io.File.stdout(), testing.io, &w_buf);
    try printStruct(&writer.interface, streaminfo);
    std.debug.print("\n", .{});
    try writer.flush();
}
