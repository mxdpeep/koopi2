package main

import (
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/chai2010/webp"
)

func main() {
	paths := []string{"./images", "./markets-v2"}
	var wg sync.WaitGroup
	var converted, skipped, errors int64

	for _, root := range paths {
		filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}

			ext := strings.ToLower(filepath.Ext(path))
			if ext == ".jpg" || ext == ".png" {
				webpPath := strings.TrimSuffix(path, ext) + ".webp"

				wInfo, err := os.Stat(webpPath)
				if err == nil && !info.ModTime().After(wInfo.ModTime()) {
					atomic.AddInt64(&skipped, 1)
					return nil
				}

				wg.Add(1)
				go func(in, out string) {
					defer wg.Done()
					if err := convert(in, out); err != nil {
						atomic.AddInt64(&errors, 1)
					} else {
						atomic.AddInt64(&converted, 1)
					}
				}(path, webpPath)
			}
			return nil
		})
	}
	wg.Wait()

	fmt.Printf("WebP conversion finished: %d converted, %d skipped", converted, skipped)
	if errors > 0 {
		fmt.Printf(", %d errors", errors)
	}
	fmt.Println(".")
}

func convert(in, out string) error {
	f, err := os.Open(in)
	if err != nil {
		fmt.Printf("Open: Error converting %s: %v\n", in, err)
		return err
	}
	defer f.Close()

	img, _, err := image.Decode(f)
	if err != nil {
		fmt.Printf("Decode: Error converting %s: %v\n", in, err)
		cmd := exec.Command("convert", in, "-quality", "80", out)
		if err := cmd.Run(); err != nil {
			log.Printf("ImageMagick failed on %s: %v", in, err)
			return err
		}
		return nil
	}

	outF, err := os.Create(out)
	if err != nil {
		fmt.Printf("Create: Error converting %s: %v\n", in, err)
		return err
	}
	defer outF.Close()

	err = webp.Encode(outF, img, &webp.Options{Quality: 80})
	if err != nil {
		fmt.Printf("Encode: Error converting %s: %v\n", in, err)
		return err
	}
	return nil
}
