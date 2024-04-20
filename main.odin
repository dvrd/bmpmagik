package image_processing

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"

BMP_SIG :: []byte{'4', '2', '4', 'd'}

BMP_CompressionType :: enum {
	RGB  = 0,
	RLE8 = 1,
	RLE4 = 2,
}

BMP_Image :: struct {
	size:             u32,
	width:            u32,
	height:           u32,
	data_offset:      u32,
	bitmap_size:      u32,
	planes:           u16,
	bit_depth:        u16,
	compression_type: BMP_CompressionType,
	img_size:         u32,
	x_ppm:            u32,
	y_ppm:            u32,
	colors_used:      u32,
	important_colors: u32,
	color_table:      []byte,
	data:             []byte,
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

	img.width = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.height = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.planes = endian.get_u16(bytes.buffer_next(&buf, 2), .Little) or_return
	img.bit_depth = endian.get_u16(bytes.buffer_next(&buf, 2), .Little) or_return

	img.compression_type =
	cast(BMP_CompressionType)endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.img_size = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	if img.img_size == 0 && img.compression_type != .RGB do return nil, false

	img.x_ppm = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.y_ppm = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	img.colors_used = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return
	img.important_colors = endian.get_u32(bytes.buffer_next(&buf, 4), .Little) or_return

	if img.bit_depth <= 8 {
		color_table := [1024]byte {
			0 ..< 1024 = 0,
		}
		bits, io_err = io.read(stream, color_table[:])
		if io_err != nil || bits != 1024 do return nil, false
		img.color_table = color_table[:]
	}

	data := make([]byte, img.img_size)
	defer delete(data)
	bits, io_err = io.read(stream, data)
	img.data = data

	return img, true
}

write_bmp :: proc(img: ^BMP_Image, path: string) -> (ok: bool) {
	fd, errno := os.open(
		path,
		os.O_WRONLY | os.O_TRUNC | os.O_CREATE,
		os.S_IRUSR | os.S_IRGRP | os.S_IROTH | os.S_IWUSR,
	)
	sig := hex.decode(BMP_SIG) or_return

	stream := os.stream_from_handle(fd)
	bits, io_err := io.write(stream, sig)
	if io_err != nil || bits != 2 do return false

	bit32_buf := [4]byte{0, 0, 0, 0}
	endian.put_u32(bit32_buf, .Little, img.size)
	bits, io_err := io.write(stream, bit32_buf)
	clear(bit32_buf)
	bits, io_err := io.write(stream, bit32_buf)
	endian.put_u32(bit32_buf, .Little, img.data_offset)

	return true
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}


	src := "./images/lena512.bmp"
	target := "./images/lena_copy.bmp"

	img, ok := read_bmp(src)
	if !ok do fmt.panicf("Failed to read the BMP file")
	defer free(img)

	fmt.printfln("Image Size: %M", img.img_size)
	write_bmp(img, target)
}
