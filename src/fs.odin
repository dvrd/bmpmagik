package bmpmagik

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:os"

read_bmp :: proc(path: string) -> (img: ^BMP_Image, ok: bool) {
	header := [54]byte {
		0 ..< 54 = 0,
	}
	img = new(BMP_Image)

	fd, errno := os.open(path)
	if errno != os.ERROR_NONE do return nil, false
	defer os.close(fd)

	stream := os.stream_from_handle(fd)
	bits, io_err := io.read(stream, header[:])
	if io_err != nil || bits != 54 do return nil, false

	buf: bytes.Buffer
	defer bytes.buffer_destroy(&buf)
	bytes.buffer_init(&buf, header[:])

	sig := bytes.buffer_next(&buf, 2)
	encoded_sig := transmute(string)hex.encode(sig)
	defer delete(encoded_sig)
	if encoded_sig != transmute(string)BMP_SIG do return nil, false

	img.size = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	bytes.buffer_next(&buf, 4) // reserved must be zeros

	img.data_offset = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	img.bitmap_size = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	if img.bitmap_size != 40 do return nil, false

	img.width = cast(int)endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.height = cast(int)endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	img.planes = endian.get_u16(bytes.buffer_next(&buf, 2), .Little) or_return
	img.bit_depth = endian.get_u16(bytes.buffer_next(&buf, 2), .Little) or_return

	img.compression_type =
	cast(BMP_CompressionType)endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.img_size = cast(int)endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	if img.img_size == 0 && img.compression_type != .RGB do return nil, false

	img.x_ppm = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.y_ppm = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	img.colors_used = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.important_colors = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	if img.bit_depth <= 8 {
		color_table := make([]byte, 1024)
		defer delete(color_table)
		bits, io_err = io.read(stream, color_table)
		if io_err != nil || bits != 1024 do return nil, false
		img.color_table = color_table
	}

	data := make(Img, img.height)
	img.data = data
	loop: for x := 0; x < img.height; x += 1 {
		data[x] = make([]Pixel, img.width)
		for y := 0; y < img.width; y += 1 {
			if img.colors_used == 0 {
				img.data[x][y].b, io_err = io.read_byte(stream)
				if io_err == .EOF do break loop
				img.data[x][y].g, io_err = io.read_byte(stream)
				if io_err == .EOF do break loop
				img.data[x][y].r, io_err = io.read_byte(stream)
				if io_err == .EOF do break loop
			} else {
				pixel: byte
				pixel, io_err = io.read_byte(stream)
				if io_err == .EOF do break loop
				img.data[x][y].b = pixel
				img.data[x][y].g = pixel
				img.data[x][y].r = pixel
			}
		}
	}

	return img, true
}

write_bmp :: proc(img: ^BMP_Image, path: string) -> (ok: bool) {
	fd, errno := os.open(
		path,
		os.O_WRONLY | os.O_TRUNC | os.O_CREATE,
		os.S_IRUSR | os.S_IRGRP | os.S_IROTH | os.S_IWUSR,
	)
	defer os.close(fd)

	sig := hex.decode(BMP_SIG) or_return
	defer delete(sig)

	stream := os.stream_from_handle(fd)
	bits, io_err := io.write(stream, sig)
	if io_err != nil || bits != 2 do return false

	bit32_buf := [4]byte{0, 0, 0, 0}
	bit16_buf := [2]byte{0, 0}

	endian.put_u32(bit32_buf[:], .Little, img.size)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	bits, io_err = io.write(stream, []byte{0, 0, 0, 0})
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.data_offset)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.bitmap_size)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, cast(u32)img.width)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, cast(u32)img.height)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u16(bit16_buf[:], .Little, img.planes)
	bits, io_err = io.write(stream, bit16_buf[:])
	if io_err != nil || bits != 2 do return false

	endian.put_u16(bit16_buf[:], .Little, img.bit_depth)
	bits, io_err = io.write(stream, bit16_buf[:])
	if io_err != nil || bits != 2 do return false

	endian.put_u32(bit32_buf[:], .Little, u32(img.compression_type))
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, cast(u32)img.img_size)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.x_ppm)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.y_ppm)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.colors_used)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	endian.put_u32(bit32_buf[:], .Little, img.important_colors)
	bits, io_err = io.write(stream, bit32_buf[:])
	if io_err != nil || bits != 4 do return false

	if img.bit_depth <= 8 {
		bits, io_err = io.write(stream, img.color_table)
		if io_err != nil || bits != 1024 do return false
	}

	for row in img.data {
		for pixel in row {
			if img.colors_used == 0 {
				io_err = io.write_byte(stream, pixel.b)
				if io_err != nil do return false
				io_err = io.write_byte(stream, pixel.g)
				if io_err != nil do return false
				io_err = io.write_byte(stream, pixel.r)
				if io_err != nil do return false
			} else {
				io_err = io.write_byte(stream, pixel.r)
				if io_err != nil do return false
			}
		}
	}

	return true
}
