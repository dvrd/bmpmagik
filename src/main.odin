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
import "core:slice"

main :: proc() {
	src := slice.get(os.args, 1) or_else "./images/lena_color.bmp"
	target := "./images/lena_copy.bmp"

	img, ok := read_bmp(src)
	if !ok do fmt.panicf("Failed to read the BMP file")
	defer delete_bmp(img)

	fmt.printfln("file size: %M", img.size)
	fmt.println("size in bytes:", img.img_size)
	fmt.println("width in pixels:", img.width)
	fmt.println("height in pixels:", img.width)

	rotate180(img)

	write_bmp(img, target)
}
