const std = @import("std");

const width: usize = 160;
const height: usize = 44;
const background_ascii_code: u8 = ' ';

const distance_from_cam: f32 = 100.0;
const K1: f32 = 40.0;
const increment_speed: f32 = 0.6;

const Renderer = struct {
    a: f32 = 0.0,
    b: f32 = 0.0,
    c: f32 = 0.0,

    cube_width: f32 = undefined,
    horizontal_offset: f32 = undefined,

    z_buffer: [width * height]f32 = undefined,
    buffer: [width * height]u8 = undefined,

    fn calculate_x(self: *const Renderer, i: f32, j: f32, k: f32) f32 {
        return j * @sin(self.a) * @sin(self.b) * @cos(self.c) - k * @cos(self.a) * @sin(self.b) * @cos(self.c) + j * @sin(self.a) * @sin(self.c) + k * @sin(self.a) * @sin(self.c) + i * @cos(self.b) * @cos(self.c);
    }

    fn calculate_y(self: *const Renderer, i: f32, j: f32, k: f32) f32 {
        return j * @cos(self.a) * @cos(self.c) + k * @sin(self.a) * @cos(self.c) - j * @sin(self.a) * @sin(self.b) * @sin(self.c) + k * @cos(self.a) * @sin(self.b) * @sin(self.c) - i * @cos(self.b) * @sin(self.c);
    }

    fn calculate_z(self: *const Renderer, i: f32, j: f32, k: f32) f32 {
        return k * @cos(self.a) * @cos(self.b) - j * @sin(self.a) * @cos(self.b) + i * @sin(self.b);
    }

    fn calculate_for_surface(
        self: *Renderer,
        cube_x: f32,
        cube_y: f32,
        cube_z: f32,
        ch: u8,
    ) void {
        const x = self.calculate_x(cube_x, cube_y, cube_z);
        const y = self.calculate_y(cube_x, cube_y, cube_z);
        const z = self.calculate_z(cube_x, cube_y, cube_z) + distance_from_cam;

        const ooz = 1.0 / z;

        const width_f = @as(f32, @floatFromInt(width));
        const height_f = @as(f32, @floatFromInt(height));

        const xp: i32 = @intFromFloat(width_f / 2.0 + self.horizontal_offset + K1 * ooz * x * 2);
        const yp: i32 = @intFromFloat(height_f / 2.0 + K1 * ooz * y);

        if (xp >= 0 and xp < width and yp >= 0 and yp < height) {
            const idx: usize = @intCast(xp + yp * @as(i32, @intCast(width)));

            if (ooz > self.z_buffer[idx]) {
                self.z_buffer[idx] = ooz;
                self.buffer[idx] = ch;
            }
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.print("\x1b[2J", .{});
    try stdout_writer.flush();

    var renderer = Renderer{};

    while (true) {
        @memset(&renderer.buffer, background_ascii_code);
        @memset(&renderer.z_buffer, 0.0);

        renderer.cube_width = 20.0;
        renderer.horizontal_offset = -2.0 * renderer.cube_width;

        var cube_x = -renderer.cube_width;

        while (cube_x < renderer.cube_width) : (cube_x += increment_speed) {
            var cube_y = -renderer.cube_width;

            while (cube_y < renderer.cube_width) : (cube_y += increment_speed) {
                renderer.calculate_for_surface(cube_x, cube_y, -renderer.cube_width, '@');
                renderer.calculate_for_surface(renderer.cube_width, cube_y, cube_y, '$');
                renderer.calculate_for_surface(-renderer.cube_width, cube_y, -cube_x, '~');

                renderer.calculate_for_surface(-cube_x, cube_y, renderer.cube_width, '#');
                renderer.calculate_for_surface(cube_x, -renderer.cube_width, -cube_y, ';');
                renderer.calculate_for_surface(cube_x, renderer.cube_width, cube_y, '+');
            }
        }

        try stdout_writer.print("\x1b[H", .{});
        var y: usize = 0;
        while (y < height) : (y += 1) {
            const row_start = y * width;
            const row_end = row_start + width;

            try stdout_writer.print("{s}\n", .{renderer.buffer[row_start..row_end]});
        }

        try stdout_writer.flush();

        renderer.a += 0.015;
        renderer.b += 0.015;
        renderer.c += 0.003;

        const duration = std.Io.Duration.fromMilliseconds(16);
        try io.sleep(duration, .real);
    }
}
