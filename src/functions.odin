package bmpmagik

import "core:math/bits"
import "core:fmt"
import "core:slice"

greyscale :: proc(img: ^BMP_Image) {
	for &pixel in img.data do pixel = 255 - pixel
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
	for &pixel in img.data do pixel = brighten_pixel(pixel, factor)
}

halftone :: proc(img: ^BMP_Image, threshold: u8 = 127) {
	for &pixel in img.data {
		for &channel in pixel {
			channel = channel > threshold ? 255 : 0
		}
	}
}

rgb_to_grey :: proc(img: ^BMP_Image) {
	if img.bit_depth != 24 do return
	tmp: f64
	for &pixel in img.data {
			tmp =
				(cast(f64)pixel.r * 0.3) +
				(cast(f64)pixel.g * 0.59) +
				(cast(f64)pixel.b * 0.11)
			pixel = cast(u8)tmp
	}
}

NINTH :: matrix[3, 3]f64{0..<9=1.0/9.0};
blur :: proc(img: ^BMP_Image, kernel := NINTH) {
	cur_pixel: Pixel
	new_pixel: [3]f64
	for y := 1; y < img.height - 1; y += 1 {
		for x := 1; x < img.width - 1; x += 1 {
			new_pixel = {0,0,0}
			cur_pixel = {0,0,0}
			for i := -1; i <= 1; i += 1{
				for j := -1; j <= 1; j += 1 {
					cur_pixel = pixel_at(img, x + i, y + j)^
					new_pixel.r += kernel[i + 1, j + 1] * cast(f64)cur_pixel.r;
					new_pixel.g += kernel[i + 1, j + 1] * cast(f64)cur_pixel.g;
					new_pixel.b += kernel[i + 1, j + 1] * cast(f64)cur_pixel.b;
				}
			}
			cur_pixel.r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
			cur_pixel.g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
			cur_pixel.b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
			pixel_at(img, x, y)^ = cur_pixel
		}
	}
}

sepia :: proc(img: ^BMP_Image) {
	new_pixel: [3]f64
	for &pixel in img.data {
		new_pixel.r = (cast(f64)pixel.r * 0.393) + (cast(f64)pixel.g * 0.769)	+ (cast(f64)pixel.b * 0.189);
		new_pixel.g = (cast(f64)pixel.r * 0.349) + (cast(f64)pixel.g * 0.686)	+ (cast(f64)pixel.b * 0.168);
		new_pixel.b = (cast(f64)pixel.r * 0.272) + (cast(f64)pixel.g * 0.534)	+ (cast(f64)pixel.b * 0.131);
		pixel.r = new_pixel.r > 255 ? 255 : cast(u8)new_pixel.r
		pixel.g = new_pixel.g > 255 ? 255 : cast(u8)new_pixel.g
		pixel.b = new_pixel.b > 255 ? 255 : cast(u8)new_pixel.b
	}
}

rotate :: proc(img: ^BMP_Image, angle: int) {
	switch angle {
	case 90: rotate90(img)
	case 180: rotate180(img)
	case 270: rotate90(img); rotate180(img)
	case: fmt.println("Invalid angle")
	}
}

rotate180 :: proc(img: ^BMP_Image) {
	tmp: Pixel
	row, col: int
	data_copy := make([]Pixel, img.height * img.width)
	for x := 0; x < img.height - 1; x += 1 {
		for y := 0; y < img.width - 1; y += 1 {
			row = (img.height - 1 - y) * img.width
			col = img.width - 1 - x
			data_copy[row + col] = pixel_at(img, x, y)^
		}
	}
	delete(img.data)
	img.data = data_copy
}

rotate90 :: proc(img: ^BMP_Image) {
	tmp: Pixel
	row, col: int
	data_copy := make([]Pixel, img.height * img.width)
	for x := 0; x < img.height - 1; x += 1 {
		for y := 0; y < img.width - 1; y += 1 {
			data_copy[x * img.width + y] = pixel_at(img, x, y)^
		}
	}
	delete(img.data)
	img.data = data_copy
}

