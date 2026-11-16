const std = @import("std");
const io =  std.Io;

pub fn readBit(slices: []const u8, pos: usize) !u1 {
    // using a lot of @truncate here because the need of
    // satisfying the compiler complaints of asserting u3's
    return if (pos < slices.len * 8) 
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

// unknown BUT i hope the compiler doesnt complain ts
// how the fuck would i know to do the rhs??
pub fn readBitC(comptime T: type, value: T, pos: usize) !u1 {
    const size: usize = @bitSizeOf(T);
    if (pos < size) {
        const rhs: std.math.Log2Int(T) = @intCast(size - 1 - pos);
        return @truncate((value >> rhs)); 
    }
    return error.OutOfBounds;
}

test "readBitC" {
    const val1: u1  = 0;
    const val2: u1  = 1;
    const val3: u8  = 0xF0;
    const val4: u13 = 0b0101011001101;

    try std.testing.expectEqual(0, try readBitC(@TypeOf(val1), val1, 0));
    try std.testing.expectEqual(1, try readBitC(@TypeOf(val2), val2, 0));
    try std.testing.expectEqual(1, try readBitC(@TypeOf(val3), val3, 3));
    try std.testing.expectEqual(0, try readBitC(@TypeOf(val3), val3, 4));

    try std.testing.expectEqual(0, try readBitC(@TypeOf(val4), val4, 0));
    try std.testing.expectEqual(1, try readBitC(@TypeOf(val4), val4, 1));
    try std.testing.expectEqual(0, try readBitC(@TypeOf(val4), val4, 2));
    try std.testing.expectEqual(1, try readBitC(@TypeOf(val4), val4, 3));

    try std.testing.expectError(error.OutOfBounds, readBitC(@TypeOf(val4), val4, 13));
    try std.testing.expectError(error.OutOfBounds, readBitC(@TypeOf(val4), val4, 17));
    try std.testing.expectError(error.OutOfBounds, readBitC(@TypeOf(val4), val4, 9999));
}

pub fn readBits(slices: []const u8, pos: *usize, n: usize) !usize {
    if (n > @bitSizeOf(usize)) return error.IncorrectValue;
    var value: usize = 0;
    for (0.. n) |i| {
        const bit = try readBit(slices, pos.* + i);
        value <<= 1;
        value |= @as(usize, bit);
    } 

    // if the reading above fails, the entire function fails
    // so then nothing gets modified...
    pos.* = pos.* + n;
    
    return value;
}

test "readBits" {
    const slices: []const u8 = 
        &.{
            0b00001111, 
            0b11001100, 
            0b11110000, 
            0b01010101,
            0b00001111, 
            0b11001100, 
            0b11110000, 
            0b01010101
        };

    var pos: usize = 0;
    const incorrect = readBits(slices, &pos, 100);

    try std.testing.expectError(error.IncorrectValue, incorrect);
    try std.testing.expectEqual(0, pos);

    const res1 = try readBits(slices, &pos, 4);
    try std.testing.expectEqual(@as(usize, 0), res1);
    try std.testing.expectEqual(4, pos);

    const res2 = try readBits(slices, &pos, 2);
    try std.testing.expectEqual(@as(usize, 0b11), res2);
    try std.testing.expectEqual(6, pos);

    const res3 = try readBits(slices, &pos, 3);
    try std.testing.expectEqual(@as(usize, 0b111), res3);
    try std.testing.expectEqual(9, pos);

    const res4 = try readBits(slices, &pos, 7);
    try std.testing.expectEqual(@as(usize, 0b1001100), res4);
    try std.testing.expectEqual(16, pos);

    const res5 = try readBits(slices, &pos, 48);
    try std.testing.expectEqual(@as(usize, 0xF0550FCCF055), res5);
    try std.testing.expectEqual(64, pos);

    // inner readBit will fail cause out of bounds
    // therefore pos should not update and returned
    // with OutOfBounds
    const res6 = readBits(slices, &pos, 5);
    try std.testing.expectError(error.OutOfBounds, res6);
    try std.testing.expectEqual(64, pos);
}

pub fn readBitsC(comptime T: type, value: T, pos: *usize, n: usize) !T {
    // function call provides type
    // from the value we shift type T once
    if (n > @bitSizeOf(T)) return error.IncorrectValue;

    // i freakin hope they just cast this as T without any complaint
    var val: T = 0;
    for (0.. n) |i| {
        const bit = try readBitC(T, value, pos.* + i);
        val <<= 1;
        val |= @as(T, bit);
    } 

    // if the reading above fails, the entire function fails
    // so then nothing gets modified...
    pos.* = pos.* + n;
    
    return val;
}

test "readBitsC" {
    const value: u64 = 0xFF00AA00F0F000FF;

    var pos: usize = 0;
    const incorrect = readBitsC(@TypeOf(value), value, &pos, 100);
    try std.testing.expectError(error.IncorrectValue, incorrect);
    try std.testing.expectEqual(0, pos);

    const res1 = try readBitsC(@TypeOf(value), value, &pos, 8);
    try std.testing.expectEqual(@as(@TypeOf(value), 0xFF), res1);
    try std.testing.expectEqual(8, pos);

    const res2 = try readBitsC(@TypeOf(value), value, &pos, 8);
    try std.testing.expectEqual(@as(@TypeOf(value), 0), res2);
    try std.testing.expectEqual(16, pos);

    const res3 = try readBitsC(@TypeOf(value), value, &pos, 2);
    try std.testing.expectEqual(@as(@TypeOf(value), 0b10), res3);
    try std.testing.expectEqual(18, pos);

    const res4 = try readBitsC(@TypeOf(value), value, &pos, 3);
    try std.testing.expectEqual(@as(@TypeOf(value), 0b101), res4);
    try std.testing.expectEqual(21, pos);

    const res5 = try readBitsC(@TypeOf(value), value, &pos, 3);
    try std.testing.expectEqual(@as(@TypeOf(value), 0b010), res5);
    try std.testing.expectEqual(24, pos);

    const res6 = try readBitsC(@TypeOf(value), value, &pos, 40);
    try std.testing.expectEqual(@as(@TypeOf(value), 0x00F0F000FF), res6);
    try std.testing.expectEqual(64, pos);

    // inner readBit will fail cause out of bounds
    // therefore pos should not update and returned
    // with OutOfBounds
    const res7 = readBitsC(@TypeOf(value), value, &pos, 5);
    try std.testing.expectError(error.OutOfBounds, res7);
    try std.testing.expectEqual(64, pos);
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
