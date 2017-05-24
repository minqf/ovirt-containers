/*
Copyright (c) 2017 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

// This tool untas all the images created by the project, so that the
// next build will create them again.

import (
	"fmt"
	"os"

	"ovirt/build"
)

func main() {
	// Load the images:
	images := build.LoadImages()

	// The list of images is always returned in build order, with
	// base images before the images that depend on them. In order
	// to remove them without issues we need to reverse that order,
	// so that base images are removed after the images that depend
	// on them.
	for i := len(images) - 1; i >= 0; i-- {
		image := images[i]
		fmt.Printf("Remove image '%s'\n", image)
		err := image.Remove()
		if err != nil {
			fmt.Fprintf(
				os.Stderr, "Failed to remove image '%s'\n",
				image,
			)
			os.Exit(1)
		}
	}
}
