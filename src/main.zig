const std = @import("std");

const zig_serial = @import("serial");




pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
//    const stderr = std.io.getStdErr().writer();
    var loadcell_port: []const u8 = undefined;
    const prefix: []const u8 = "\\\\.\\";
    var iterator = try zig_serial.list_info();
    defer iterator.deinit();

    while (try iterator.next()) |info| {
        if (info.vid == 0x403) {
            loadcell_port = info.port_name;
        }
    }
    try stdout.print("\nFound Loadcell! Port name: {s}\n", .{loadcell_port});
    try stdout.print("Attempting to connect to loadcell on Port: {s}\n", .{loadcell_port});

    const filepath_parts: []const []const u8 = &.{prefix, loadcell_port};
    const loadcell_name = std.mem.concat(allocator, u8, filepath_parts) catch unreachable;
    defer allocator.free(loadcell_name);
   
    var serial = std.fs.cwd().openFile(loadcell_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{loadcell_name});
            return 1;
    },
    else => return err,
    };
    defer serial.close();

    const file = try std.fs.cwd().createFile("test.txt", .{});
    defer file.close();

    var fw = file.writer();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 230400,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    var buf: [1024]u8 = undefined;

    try serial.writer().writeAll("MODEL\r");
    const model = try serial.reader().readUntilDelimiter(&buf, '\n');
    try stdout.print("Model: {s}\n", .{model});

    try serial.writer().writeAll("UNITS\r");
    const units = try serial.reader().readUntilDelimiter(&buf, '\n');
    try stdout.print("Units: {s}\n", .{units});

    try serial.writer().writeAll("ID\r");
    const id = try serial.reader().readUntilDelimiter(&buf, '\n');
    try stdout.print("ID: {s}\n", .{id});

    const start = try stdin.readUntilDelimiter(&buf, '\r');

    try serial.writer().writeAll(start);
    try serial.writer().writeByte('\r');

    for (0..10000) |_| {
        const line = try serial.reader().readUntilDelimiter(&buf, '\r');
        try stdout.print("{s}", .{line});
        _ = try fw.writeAll(line);
    }

    return 0;
}

