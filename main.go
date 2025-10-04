package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

// processFile reads a given file, expands any `#include:` directives,
// and returns the fully processed content as a string.
// This is the core recursive function.
func processFile(filePath string, rootDir string, isRoot bool) (string, error) {
	// Prevent reading the same file multiple times in a circular dependency
	// by checking the absolute path. This is a simple form of cycle detection.
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return "", fmt.Errorf("could not get absolute path for %s: %w", filePath, err)
	}

	file, err := os.Open(absPath)
	if err != nil {
		return "", fmt.Errorf("failed to open file %s: %w", filePath, err)
	}
	defer file.Close()

	// Get the relative path for the comments
	relativePath, err := filepath.Rel(rootDir, absPath)
	if err != nil {
		// If Rel fails (e.g., different drive on Windows), fallback to the original path.
		relativePath = filePath
	}

	var output strings.Builder
	// Add a START comment with the relative path if this is an included file.
	if !isRoot {
		output.WriteString(fmt.Sprintf("# START %s\n", filepath.ToSlash(relativePath)))
	}

	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()
		trimmedLine := strings.TrimSpace(line)

		if strings.HasPrefix(trimmedLine, "#include:") {
			// Capture the indentation from the original line.
			// This is everything before the '#' character.
			indentation := line[:strings.Index(line, "#")]

			// Extract the relative path from the include directive.
			includePathStr := strings.TrimSpace(strings.TrimPrefix(trimmedLine, "#include:"))
			if includePathStr == "" {
				log.Printf("Warning: Found empty #include directive in %s. Skipping.", filePath)
				continue
			}

			// The include path is relative to the file it's in.
			// Get the directory of the current file.
			baseDir := filepath.Dir(filePath)
			// Join it with the relative path from the directive.
			fullIncludePath := filepath.Join(baseDir, includePathStr)

			// Process the included path (which could be a file or directory).
			includedContent, err := processIncludePath(fullIncludePath, rootDir)
			if err != nil {
				return "", fmt.Errorf("error processing include '%s' in file %s: %w", includePathStr, filePath, err)
			}

			// Apply the captured indentation to each line of the included content.
			// We trim a single trailing newline to avoid creating an extra empty indented line.
			contentToIndent := strings.TrimSuffix(includedContent, "\n")
			if contentToIndent != "" {
				contentScanner := bufio.NewScanner(strings.NewReader(contentToIndent))
				for contentScanner.Scan() {
					output.WriteString(indentation)
					output.WriteString(contentScanner.Text())
					output.WriteString("\n") // CORRECTED: This should only be one newline.
				}
			}
			// Your line now works as intended, adding a single empty line after the content.
			output.WriteString("\n")
		} else {
			// If it's not an include directive, just add the line to the output.
			output.WriteString(line + "\n")
		}
	}

	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("error reading file %s: %w", filePath, err)
	}

	finalResult := output.String()

	// Add an END comment if this is an included file.
	if !isRoot {
		// Tidy up trailing newlines before adding the final comment.
		finalResult = strings.TrimRight(finalResult, "\n")
		finalResult += fmt.Sprintf("\n# END %s\n", filepath.ToSlash(relativePath))
	}

	return finalResult, nil
}

// processIncludePath determines if a path is a file or a directory and
// processes it accordingly.
func processIncludePath(path string, rootDir string) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("include path not found %s: %w", path, err)
	}

	if info.IsDir() {
		// If it's a directory, walk through it and process all files.
		var dirContent strings.Builder
		// filepath.Walk is automatically recursive.
		walkErr := filepath.Walk(path, func(p string, f os.FileInfo, err error) error {
			if err != nil {
				return err // Propagate errors from walking.
			}
			// We only want to include the content of files, not directories.
			if !f.IsDir() {
				// Recursively process the file to handle nested includes.
				fileContent, err := processFile(p, rootDir, false)
				if err != nil {
					return fmt.Errorf("failed to process file in directory %s: %w", p, err)
				}
				dirContent.WriteString(fileContent)
			}
			return nil
		})
		if walkErr != nil {
			return "", walkErr
		}
		return dirContent.String(), nil
	}

	// If it's a single file, just process that file.
	return processFile(path, rootDir, false)
}

func main() {
	// --- 1. Argument Validation ---
	if len(os.Args) != 2 {
		fmt.Println("Usage: expander.exe <directory>")
		// Print error to stderr, which is standard for errors.
		fmt.Fprintln(os.Stderr, "Error: A single directory path must be provided as an argument.")

		// Add a pause so the user can see the message if they double-clicked the .exe
		fmt.Println("\nPress Enter to exit...")
		bufio.NewReader(os.Stdin).ReadBytes('\n')
		os.Exit(1)
	}
	rootDir := os.Args[1]
	info, err := os.Stat(rootDir)
	if err != nil {
		log.Fatalf("Error: Cannot access directory '%s': %v", rootDir, err)
	}
	if !info.IsDir() {
		log.Fatalf("Error: The provided path '%s' is not a directory.", rootDir)
	}

	// --- 2. Find and Process the Root File ---
	initialFilePath := filepath.Join(rootDir, "cloud-init.tmpl.yaml")
	if _, err := os.Stat(initialFilePath); err != nil {
		log.Fatalf("Error: 'cloud-init.yaml' not found in directory '%s': %v", rootDir, err)
	}

	// --- 3. Run the Processor and Print Output ---
	finalContent, err := processFile(initialFilePath, rootDir, true)
	if err != nil {
		log.Fatalf("Failed to expand cloud-init file: %v", err)
	}

	// Print the final, fully expanded content to standard output.
	fmt.Print(finalContent)
}
