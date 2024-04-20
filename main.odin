package image_processing

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:math/bits"
import "core:mem"
import "core:os"

BMP_SIG :: []byte{'4', '2', '4', 'd'}

BMP_CompressionType :: enum {
	RGB  = 0,
	RLE8 = 1,
	RLE4 = 2,
}

Pixel :: [3]u8

BMP_Image :: struct {
	size:             u32,
	width:            int,
	height:           int,
	data_offset:      u32,
	bitmap_size:      u32,
	planes:           u16,
	bit_depth:        u16,
	compression_type: BMP_CompressionType,
	img_size:         int,
	x_ppm:            u32,
	y_ppm:            u32,
	colors_used:      u32,
	important_colors: u32,
	color_table:      []byte,
	data:             []Pixel,
}

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

	data := make([]Pixel, img.img_size / 3)
	defer delete(data)

	img.data = data
	for i := 0; io_err != .EOF && i < len(data); i += 1 {
		img.data[i].b, io_err = io.read_byte(stream)
		img.data[i].g, io_err = io.read_byte(stream)
		img.data[i].r, io_err = io.read_byte(stream)
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

	for &pixel in img.data {
		io_err = io.write_byte(stream, pixel.b)
		if io_err != nil do return false
		io_err = io.write_byte(stream, pixel.g)
		if io_err != nil do return false
		io_err = io.write_byte(stream, pixel.r)
		if io_err != nil do return false
	}

	return true
}

grayscale :: proc(img: ^BMP_Image) {
	for i := 0; i < img.height; i += 1 {
		for j := 0; j < img.width; j += 1 {
			img.data[i * img.width + j] = 255 - img.data[i * img.width + j]
		}
	}
}

brighten_pixel :: proc(pixel: Pixel, factor: u8) -> (new_pixel: Pixel) {
	brighter: u8
	did_overflow: bool
	for channel, idx in pixel {
		brighter, did_overflow = bits.overflowing_add(channel, factor)
		new_pixel[idx] = did_overflow ? 255 : brighter
	}
	return
}

brighten :: proc(img: ^BMP_Image, factor: u8) {
	for i := 0; i < img.width * img.height; i += 1 {
		img.data[i] = brighten_pixel(img.data[i], factor)
	}
}

halftone :: proc(img: ^BMP_Image, threshold: u8) {
	for i := 0; i < img.width * img.height; i += 1 {
		for &channel in img.data[i] {
			channel = channel > threshold ? 255 : 0;
		}
	}
}

rgb_to_gray :: proc(img: ^BMP_Image) {
	cur_pixel: Pixel
	y: f64
	for i := 0; i < img.height * img.width; i += 1 {
		cur_pixel = img.data[i]
		y = (cast(f64)cur_pixel.r * 0.3) + (cast(f64)cur_pixel.g * 0.59) + (cast(f64)cur_pixel.b * 0.11);
		img.data[i] = cast(u8)y
	}
}

GAUSSIAN :: matrix[3, 3]f64{0..<9=1.0/9.0};
blur :: proc(img: ^BMP_Image, kernel := GAUSSIAN) {
	cur_pixel: Pixel
	new_pixel: [3]f64
	for x := 1; x < img.height - 1; x += 1 {
		for y := 1; y < img.width - 1; y += 1 {
			new_pixel = {0,0,0}
			cur_pixel = {0,0,0}
			for i := -1; i <= 1; i += 1{
				for j := -1; j <= 1; j += 1 {
					cur_pixel = img.data[(x + i) * img.width + (y + j)]
					new_pixel.r += kernel[i + 1, j + 1] * cast(f64)cur_pixel.r;
					new_pixel.g += kernel[i + 1, j + 1] * cast(f64)cur_pixel.g;
					new_pixel.b += kernel[i + 1, j + 1] * cast(f64)cur_pixel.b;
				}
			}
			cur_pixel.r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
			cur_pixel.g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
			cur_pixel.b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
			img.data[x * img.width + y] = cur_pixel
		}
	}
}

sepia :: proc(img: ^BMP_Image) {
	new_pixel: [3]f64
	for i := 0; i < img.width * img.height; i += 1 {
		new_pixel.r = (cast(f64)img.data[i].r * 0.393) + (cast(f64)img.data[i].g * 0.769)	+ (cast(f64)img.data[i].b * 0.189);
		new_pixel.g = (cast(f64)img.data[i].r * 0.349) + (cast(f64)img.data[i].g * 0.686)	+ (cast(f64)img.data[i].b * 0.168);
		new_pixel.b = (cast(f64)img.data[i].r * 0.272) + (cast(f64)img.data[i].g * 0.534)	+ (cast(f64)img.data[i].b * 0.131);
		img.data[i].r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
		img.data[i].g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
		img.data[i].b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
	}
}

main :: proc() {
	src := os.args[1]
	target := "./images/lena_copy.bmp"

	img, ok := read_bmp(src)
	if !ok do fmt.panicf("Failed to read the BMP file")
	defer free(img)

	fmt.printfln("file size: %M", img.size)
	fmt.println("size in bytes:", img.img_size)
	fmt.println("width in pixels:", img.width)
	fmt.println("height in pixels:", img.width)

	rgb_to_gray(img)

	write_bmp(img, target)
}
