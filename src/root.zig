const std = @import("std");
const io =  std.Io;

pub fn readBit(slices: []const u8, pos: usize) !u1 {
    // using a lot of @truncate here because the need of
    // satisfying the compiler complaints of asserting u3's
    return if ((pos < slices.len * 8)) 
        @truncate((slices[pos / 8] >> @as(u3, @truncate(7 - (pos % 8))))) 
    else error.OutOfBounds;
}

test "readBit" {
    const val: u16 = 0b0110101011110000;
    var slices  = u16toSlices(val);
    const allocator = std.testing.allocator;
    const expectedBits = try toBits(&slices, allocator);
    defer allocator.free(expectedBits); 

    for (expectedBits, 0..) |bit, i| {
        const res = try readBit(&slices, i);
        try std.testing.expectEqual(bit, res);
    }

    try std.testing.expectError(error.OutOfBounds, readBit(&slices, 16));
    try std.testing.expectError(error.OutOfBounds, readBit(&slices, 17));
    try std.testing.expectError(error.OutOfBounds, readBit(&slices, 9999));
}

pub fn readBits(slices: []const u8, pos: *usize, n: usize) !usize {
    if (n > @bitSizeOf(usize)) return error.IncorrectValue;
    var value: usize = 0;

    for (0.. n) |i| {
        const bit = try readBit(slices, pos.* + i);
        value <<= 1;
        value |= @as(usize, bit);
    } 
    pos.* = pos.* + n;
    
    return value;
}

test "readBits" {
    var slices: [4]u8 = undefined;
    const flac: u32 = 0x66_4c_61_43;
    std.mem.writeInt(u32, &slices, flac, .big); 
    var pos: usize = 0;
    const n: usize = 32;

    const res = try readBits(&slices, &pos, n);

    try std.testing.expectEqual(pos, n);
    try std.testing.expectEqual(res, flac);

    pos = 0;
    const err = readBits(&slices, &pos, 100);
    try std.testing.expectError(error.IncorrectValue, err);
}

pub fn readBitsHeap(slices: []const u8, pos: usize, n: usize, allocator: std.mem.Allocator) ![]const u1 {
    const bits = try allocator.alloc(u1, n);
    errdefer allocator.free(bits);

    for (0.. n) |i| {
        const bit = try readBit(slices, pos + i);
        bits[i] = bit;
    } 

    return bits;
}

pub fn toBits(slices: []const u8, allocator: std.mem.Allocator) ![]const u1 {
    // the slices might be big af so we push to heap temporarily
    const bits = try allocator.alloc(u1, (slices.len) * 8); 
    
    for(0.. slices.len) |slice| {
        for (0..8) |i| {
            bits[slice * 8 + i] = @truncate(slices[slice] >> @as(u3, @truncate(7 - i)));
        } 
    }

    return bits;
}

test "toBits" {
    const val: u16 = 0b1100111100001010;
    var slices = u16toSlices(val);
    std.mem.writeInt(u16, &slices, val, std.lang.Endian.big);
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

pub fn u16toSlices(val: u16) [2]u8 {
    var slices: [2]u8 = undefined;
    std.mem.writeInt(u16, &slices , val, .big);
    return slices; 
}

test "readBitsHeap" {
    const val: u16 = 0b0110101011110000;
    const slices = u16toSlices(val);
    const allocator = std.testing.allocator;

    const a = try readBitsHeap(&slices, 0, 2, allocator);
    defer allocator.free(a);

    const b = try readBitsHeap(&slices, 15, 1, allocator);
    defer allocator.free(b);

    const c = readBitsHeap(&slices, 15, 3, allocator);

    try std.testing.expectEqualSlices(u1, &.{0,1}, a);
    try std.testing.expectEqualSlices(u1, &.{0}, b);
    try std.testing.expectError(error.OutOfBounds, c);
}

pub fn readTheFlacTextLol() void {
     
}
