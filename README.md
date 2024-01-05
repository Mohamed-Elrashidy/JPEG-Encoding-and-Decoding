# JPEG Encoding and Decoding 
## About
### Multimedia Course Project is to apply the JPEG algorithm on a WAV sound file and then decode it to get the original image.
### The project is implemented using Dart programming language.
### The project is implemented by: [Mohamed Elrashidy](https://github.com/Mohamed-Elrashidy).
### The project is supervised by: Dr. Mohamed Barbar.

## How to run The Project
### 1. Install Dart SDK from [here](https://dart.dev/get-dart).
### 2. Install any Dart IDE.
### 3. Clone the project.
### 4. Open the project in Dart IDE.
### 5. Run the project.
### 6. Select if you want to encode or decode.
### 7. Enter the file path to encode or decode.
### 8. The compressed file will be generated in the compressed_sound_files directory.
### 9. Reconstructed file will be generated in the reconstructed_sound_files directory.

## Encoding Steps
### 1. Read the WAV file.
### 2. Convert the wav file to a list of bytes.
### 3. Remove the header of the wav file.
### 4. Convert the list to a list of 8*8 blocks.
### 5. Add zero padding to make the last block size 8*8.
### 6. Subtract 128 from each block cell.
### 7. Apply DCT on each block.
### 8. Generate the quantization matrix.
### 9. Apply quantization on each block.
### 10. Apply Zigzag order on each block.
### 11. Apply RLE on the Ac Coefficients of each block.
* Count the number of consecutive zeros.
* Divide 8 bits of each byte into 4 bits for the number of zeros and 4 bits for the category of next non-zero number.
* Then add the non-zero number to the RLE List.
* Each Block Ends with 0.
* When the number of consecutive zeros is 16, add 15 to the RLE List. 
* If the rest of the block is zeros, ignore them.
### 12. Apply DPCM on the DC Coefficients of each block.
* Subtract the current DC Coefficient from the previous one.
* Add the result to the DPCM List.
* The first DC Coefficient is added as it is.
### 13. Apply Huffman Encoding on each encoded ac and dc coefficients.
* Generate Huffman Table for AC and DC Coefficients.
    * Generate the statics table for AC and DC coefficients.
    * Generate the Huffman binary Tree according to the statics table.
    * Apply the DFS algorithm on the tree to generate the Huffman Table.
* Apply Huffman Encoding on AC and DC Coefficients.
    * Get the code of each coefficient from the Huffman Table.
    * Add the code in the sequence of 0 and 1 to String Buffer.
    * Convert each 8 bits of the String Buffer to a byte and add it to the encoded list.
  
### 14. Write the encoded list to a file .bin.
## Decoding Steps
### 1. Read the encoded file.
### 2. Apply Huffman Decoding on AC and DC Coefficients.
* convert the encoded list to a string buffer.
* scan the string buffer from left to right.
* If the scanned bits' integer value is in the Huffman Table, add the coefficient to the decoded list.
* If the scanned bits' integer value is not in the Huffman Table, scan the next bit.
### 3. Apply DPCM decoding on DC Coefficients.
### 4. Apply RLE decoding on AC Coefficients.
* scan the decoded list from left to right.
* if the scanned coefficient is 15, add 16 zeros to the decoded list.
* if the scanned coefficient is 0, add the rest of the block as zeros.
* if the scanned coefficient is not 0 or 15, add the current number of zeros and the next number to the decoded list.
### 5. Generate a List of 8*8 blocks.
* Apply Zigzag order on each block, to return ac coefficients to their original order.
* Add DC coefficients to each block.
### 6. Apply Inverse Quantization on each block.
### 7. Apply Inverse DCT on each block.
### 8. Add 128 to each block cell.
### 9. Convert the list of blocks to a list of bytes.
### 10. Add the header of the WAV file.
### 11. Write the decoded list to a WAV file.





