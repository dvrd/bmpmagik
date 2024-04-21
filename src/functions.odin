package bmpmagik

import "core:math/bits"
import "core:fmt"
import "core:slice"

grayscale :: proc(img: ^BMP_Image) {
	for x := 0; x < img.width; x += 1 {
		for y := 0; y < img.height; y += 1 {
			img.data[y][x] = 255 - img.data[y][x]
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
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			img.data[x][y] = brighten_pixel(img.data[x][y], factor)
		}
	}
}

halftone :: proc(img: ^BMP_Image, threshold: u8 = 127) {
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			for &channel in img.data[x][y] {
				channel = channel > threshold ? 255 : 0
			}
		}
	}
}

rgb_to_gray :: proc(img: ^BMP_Image) {
	if img.bit_depth != 24 do return
	cur_pixel: Pixel
	tmp: f64
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			cur_pixel = img.data[x][y]
			tmp =
				(cast(f64)cur_pixel.r * 0.3) +
				(cast(f64)cur_pixel.g * 0.59) +
				(cast(f64)cur_pixel.b * 0.11)
			img.data[x][y] = cast(u8)tmp
		}
	}
}

NINTH :: matrix[3, 3]f64{0..<9=1.0/9.0};
blur :: proc(img: ^BMP_Image, kernel := NINTH) {
	cur_pixel: Pixel
	new_pixel: [3]f64
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			new_pixel = {0,0,0}
			cur_pixel = {0,0,0}
			for i := -1; i <= 1; i += 1{
				for j := -1; j <= 1; j += 1 {
					cur_pixel = img.data[x + i][y + j]
					new_pixel.r += kernel[i + 1, j + 1] * cast(f64)cur_pixel.r;
					new_pixel.g += kernel[i + 1, j + 1] * cast(f64)cur_pixel.g;
					new_pixel.b += kernel[i + 1, j + 1] * cast(f64)cur_pixel.b;
				}
			}
			cur_pixel.r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
			cur_pixel.g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
			cur_pixel.b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
			img.data[x][y] = cur_pixel
		}
	}
}

sepia :: proc(img: ^BMP_Image) {
	new_pixel: [3]f64
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			new_pixel.r = (cast(f64)img.data[x][y].r * 0.393) + (cast(f64)img.data[x][y].g * 0.769)	+ (cast(f64)img.data[x][y].b * 0.189);
			new_pixel.g = (cast(f64)img.data[x][y].r * 0.349) + (cast(f64)img.data[x][y].g * 0.686)	+ (cast(f64)img.data[x][y].b * 0.168);
			new_pixel.b = (cast(f64)img.data[x][y].r * 0.272) + (cast(f64)img.data[x][y].g * 0.534)	+ (cast(f64)img.data[x][y].b * 0.131);
			img.data[x][y].r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
			img.data[x][y].g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
			img.data[x][y].b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
		}
	}
}

rotate180 :: proc(img: ^BMP_Image) {
	tmp: Pixel
	data_copy := make(Img, img.height)
	for x := 0; x < img.height; x += 1 {
		data_copy[img.height - 1 - x] = make([]Pixel, img.width)
		for y := 0; y < img.width; y += 1 {
			data_copy[img.height - 1 - x][y] = img.data[x][y]
		}
	}
	delete_img(img.data)
	img.data = data_copy
}

rotate90 :: proc(img: ^BMP_Image) {
	tmp: Pixel
	data_copy := make(Img, img.height)
	for row, idx in img.data do data_copy[idx] = make([]Pixel, img.width)
	for x := 0; x < img.height; x += 1 {
		for y := 0; y < img.width; y += 1 {
			data_copy[y][img.width - 1 - x] = img.data[x][y]
		}
	}
	delete_img(img.data)
	img.data = data_copy
}

