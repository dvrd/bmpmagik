package bmpmagik

import "core:fmt"

BMP_SIG :: []byte{'4', '2', '4', 'd'}

BMP_CompressionType :: enum {
	RGB  = 0,
	RLE8 = 1,
	RLE4 = 2,
}

Pixel :: distinct [3]byte

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

delete_bmp :: proc(img: ^BMP_Image) {
	delete(img.data)
	free(img)
}

pixel_at :: proc(img: ^BMP_Image, x, y: int) -> ^Pixel {
	return &img.data[y * img.width + x]
}

row :: proc(img: ^BMP_Image, index: int) -> []Pixel {
    r := img.data[index * img.width:][:img.width]
    return r
}

col :: proc(img: ^BMP_Image, y: int) -> []Pixel {
	result := make([dynamic]Pixel)
	for x := 0; x < img.height; x += 1 {
		r := row(img, x)
		append(&result, r[x])
	}
	return result[:]
}

