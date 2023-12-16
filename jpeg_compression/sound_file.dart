import 'dart:io';

class SoundFile {
  String filePath;
  SoundFile({required this.filePath});

  Future<List<int>> _getSoundFileDataAsBytes() async {
    var file = File(filePath);
    var bytes = await file.readAsBytes();
    return bytes;
  }

  Future<List<List<int>>> _convertSoundBytesToMatrix() async {
    /* to work on JPEG file we need to convert list of bytes to matrix of bytes
   each dimension is dividable by 8 */
    /* we will have 8 columns and add zero padding till rows become dividable by 8 */
    List<List<int>> matrix = [];
    List<int> bytes = await _getSoundFileDataAsBytes();
    int rows = (bytes.length+7) ~/ (8 ); // to return number of rows will be exist
    int cols = 8;
    int index = 0;
    for (int i = 0; i < rows; i++) {
      List<int> row = [];
      for (int j = 0; j < cols; j++) {
        row.add(
            (index < bytes.length) ? bytes[index] : 0); // zero for zero padding
        index++;
      }
      matrix.add(row);
    }
    _makeNumberOfRowsDividableBy8(matrix);
    return matrix;
  }
  void _makeNumberOfRowsDividableBy8(List<List<int>> matrix) {
    while(matrix.length % 8 != 0) {
      matrix.add(List.filled(8, 0));
    }
  }
  getListOfBlocks() async {
    List<List<int>> matrix = await _convertSoundBytesToMatrix();
    List<List<List<int>>> blocks = [];
    for (int i = 0; i < matrix.length; i += 8) {
      List<List<int>> block = [];
      for (int j = 0; j < 8 && i + j < matrix.length; j++) {
        block.add(matrix[i + j]);
      }
      blocks.add(block);
    }
    // print("blocks at getlistofblocks is $blocks");
    return blocks;
  }


}
