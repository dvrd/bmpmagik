package bmpmagik

BMP_SIG :: []byte{'4', '2', '4', 'd'}

BMP_CompressionType :: enum {
	RGB  = 0,
	RLE8 = 1,
	RLE4 = 2,
}

Pixel :: distinct [3]byte
Img :: [][]Pixel

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
	data:             Img,
}

delete_img :: proc(img_matrix: Img) {
	for row in img_matrix do delete(row)
	delete(img_matrix)
}

delete_bmp :: proc(img: ^BMP_Image) {
	delete_img(img.data)
	free(img)
}
