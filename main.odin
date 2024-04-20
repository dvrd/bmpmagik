package bmpmagik

import "core:bytes"
import "core:encoding/endian"
import "core:encoding/hex"
import "core:fmt"
import "core:image"
import "core:io"
import "core:math/bits"
import "core:mem"
import "core:os"

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
