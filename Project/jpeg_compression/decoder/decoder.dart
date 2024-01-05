import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Decoder {
  String filePath;
  Decoder({required this.filePath});
  decode() async {
    Map<String, dynamic> data = {};
    await _getAllDataOfCompressedSoundFile(filePath, data);
    List<int> acCoefficientsWithRunLengthEncoding =
        _decodeHuffman(data["acCoefficientsWithHuffman"], data["huffmanTable"]);
    List<int> dpcmEncodedCoefficientsEncoding = _decodeHuffman(
        data["dpcmEncodedCoefficientsWithHuffman"], data["huffmanTable"]);

    List<int> quantizedDCCoefficients =
        _decodeDPCM(dpcmEncodedCoefficientsEncoding);
    List<int> runLengthDecodedACCoefficients =
        _decodeRunLengthEncoding(acCoefficientsWithRunLengthEncoding);

    List<List<List<int>>> blocks = [];
    _generateBlocks(
        quantizedDCCoefficients, runLengthDecodedACCoefficients, blocks);
    deQuantization(blocks, data["quantizationMatrix"]);
    _DCTCoefficientsReverse(blocks);
    _removeShift(blocks);
    List<int> decodedSound = [];
    _returnBlocksToList(blocks, decodedSound);
    _writeDecodedSoundToFile(decodedSound, data["metaData"], filePath);
  }

  Future<Map<String, dynamic>> decompressFromFile(String filename) async {
    final file = File(filename);

    // Read compressed data from the file
    final compressedData = await file.readAsBytes();

    // Decompress the data using ZLib
    final decompressedData = ZLibCodec().decode(compressedData);

    // Decode the decompressed data (assuming it's in JSON format)
    final decodedData = jsonDecode(utf8.decode(decompressedData));

    return decodedData;
  }

  _getAllDataOfCompressedSoundFile(
      String filePath, Map<String, dynamic> data) async {
    // get data from file
    File file = File(filePath);

    Map<String, dynamic> fileContentAsMap = await decompressFromFile(filePath);
    data["dpcmEncodedCoefficientsWithHuffman"] =
        List<int>.from(fileContentAsMap["dpcmEncodedCoefficientsWithHuffman"]);
    data["metaData"] = List<int>.from(fileContentAsMap["metaData"]);
    data["acCoefficientsWithHuffman"] =
        List<int>.from(fileContentAsMap["acCoefficientsWithHuffman"]);
    List<dynamic> temp =
        List<dynamic>.from(fileContentAsMap["quantizationMatrix"]);
    data["huffmanTableKeys"] =
        List<int>.from(fileContentAsMap["huffmanTableKeys"]);
    data["huffmanTableValues"] =
        List<String>.from(fileContentAsMap["huffmanTableValues"]);
    // format data to be used in decoder
    List<List<int>> quantizationMatrix = [];
    temp.forEach((element) {
      List<int> row = List<int>.from(element);
      quantizationMatrix.add(row);
    });
    data["quantizationMatrix"] = quantizationMatrix;

    data["huffmanTable"] = {};
    for (int i = 0; i < data["huffmanTableKeys"].length; i++) {
      data["huffmanTable"][data["huffmanTableValues"][i]] =
          data["huffmanTableKeys"][i];
    }
  }

  List<int> _decodeHuffman(
      List<int> encodedData, Map<dynamic, dynamic> huffmanTable) {
    List<int> decodedData = [];
    String bitsRepresentation = "";
    int index = 0;
    while (index < encodedData.length) {
      for (int i = 0; i < bitsRepresentation.length; i++) {
        if (huffmanTable.containsKey(bitsRepresentation.substring(0, i))) {
          decodedData.add(huffmanTable[bitsRepresentation.substring(0, i)]);
          bitsRepresentation = bitsRepresentation.substring(i);
          i = 0;
        }
      }
      bitsRepresentation +=
          encodedData[index++].toRadixString(2).padLeft(8, '0');
    }
    for (int i = 0; i < bitsRepresentation.length; i++) {
      if (huffmanTable.containsKey(bitsRepresentation.substring(0, i))) {
        decodedData.add(huffmanTable[bitsRepresentation.substring(0, i)]);
        bitsRepresentation = bitsRepresentation.substring(i);
        i = 0;
      }
    }
    return decodedData;
  }

  List<int> _decodeDPCM(List<int> dpcmEncodedCoefficientsEncoding) {
    List<int> decodedData = [];
    decodedData.add(dpcmEncodedCoefficientsEncoding[0]);
    for (int i = 1; i < dpcmEncodedCoefficientsEncoding.length; i++) {
      decodedData.add(dpcmEncodedCoefficientsEncoding[i] + decodedData[i - 1]);
    }
    return decodedData;
  }

  List<int> _decodeRunLengthEncoding(
      List<int> acCoefficientsWithRunLengthEncoding) {
    List<int> decodedData = [];
    int indexInsideBlock = 0;
    for (int i = 0; i < acCoefficientsWithRunLengthEncoding.length; i++) {
      if (acCoefficientsWithRunLengthEncoding[i] == 0) {
        while (indexInsideBlock < 64) {
          decodedData.add(0);
          indexInsideBlock++;
        }
        indexInsideBlock = 0;
      } else if (acCoefficientsWithRunLengthEncoding[i] == (15 << 4)) {
        int cnt = 16;
        while (cnt > 0) {
          decodedData.add(0);
          cnt--;
          indexInsideBlock++;
        }
      } else {
        int runLength = acCoefficientsWithRunLengthEncoding[i] >> 4;
        while (runLength > 0) {
          decodedData.add(0);
          runLength--;
          indexInsideBlock++;
        }
        i++;
        try {
          decodedData.add(acCoefficientsWithRunLengthEncoding[i]);
          indexInsideBlock++;
        } catch (e) {}
      }
    }
    return decodedData;
  }

  void _generateBlocks(List<int> quantizedDCCoefficients,
      List<int> runLengthDecodedACCoefficients, List<List<List<int>>> blocks) {
    int acCoefficientIndex = 0;
    for (int i = 0;
        i < quantizedDCCoefficients.length;
        i++, acCoefficientIndex += 63) {
      List<List<int>> block = [[], [], [], [], [], [], [], []];
      block[0].add(quantizedDCCoefficients[i]);
      _reverseZigZag(
          block,
          runLengthDecodedACCoefficients.sublist(
              acCoefficientIndex, acCoefficientIndex + 63));
      blocks.add(block);
    }
  }

  void _reverseZigZag(List<List<int>> block, List<int> sublist) {
    int index = 0;
    for (int sum = 1; sum <= 14; sum++) {
      if (sum % 2 == 0) {
        for (int row = sum; row >= 0; row--) {
          int col = sum - row;
          if (row < 8 && col < 8) {
            block[row].add(sublist[index++]);
          }
        }
      } else {
        for (int col = sum; col >= 0; col--) {
          int row = sum - col;
          if (row < 8 && col < 8) {
            block[row].add(sublist[index++]);
          }
        }
      }
    }

    /*  int numRows = block.length;
    int numCols = block[0].length;
    int index = 0;

    List<int> zigzagOrder = [];
    for (int sum = 1; sum <= numRows + numCols - 2; sum++) {
      if (sum % 2 == 0) {
        for (int row = sum; row >= 0; row--) {
          int col = sum - row;
          if (row < numRows && col < numCols) {
            block[row].add( sublist[index++]);
          }
        }
      } else {
        for (int col = sum; col >= 0; col--) {
          int row = sum - col;
          if (row < numRows && col < numCols) {
            try{
            block[row].add( sublist[index++]);}catch(e){
            }
          }
        }
      }
    }*/
  }

  void deQuantization(
      List<List<List<int>>> blocks, List<List<int>> quantizationMatrix) {
    for (int i = 0; i < blocks.length; i++) {
      for (int j = 0; j < blocks[i].length; j++) {
        for (int k = 0; k < blocks[i][j].length; k++) {
          blocks[i][j][k] *= quantizationMatrix[j][k];
        }
      }
    }
  }

  void _DCTCoefficientsReverse(List<List<List<int>>> blocks) {
    List<List<List<int>>> tempBlocks = blocks;
    for (int blockIndex = 0; blockIndex < tempBlocks.length; blockIndex++) {
      for (int targetRowIndex = 0; targetRowIndex < 8; targetRowIndex++) {
        for (int targetColIndex = 0; targetColIndex < 8; targetColIndex++) {
          double sum = 0;
          for (int sourceRowIndex = 0; sourceRowIndex < 8; sourceRowIndex++) {
            for (int sourceColIndex = 0; sourceColIndex < 8; sourceColIndex++) {
              double factor = 1;
              if (sourceRowIndex == 0 && sourceColIndex == 0)
                factor = 1 / sqrt(2);
              sum += (factor *
                  tempBlocks[blockIndex][sourceRowIndex][sourceColIndex] *
                  cos((2 * targetRowIndex + 1) * sourceRowIndex * pi / 16) *
                  cos((2 * targetColIndex + 1) * sourceColIndex * pi / 16));
            }
          }
          sum *= 0.24;
          blocks[blockIndex][targetRowIndex][targetColIndex] = sum.round();
        }
      }
    }
  }

  void _removeShift(List<List<List<int>>> blocks) {
    for (int blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      for (int rowIndex = 0; rowIndex < 8; rowIndex++) {
        for (int colIndex = 0; colIndex < 8; colIndex++) {
          blocks[blockIndex][rowIndex][colIndex] += 128;
        }
      }
    }
  }

  void _returnBlocksToList(
      List<List<List<int>>> blocks, List<int> decodedSound) {
    for (int blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      for (int rowIndex = 0; rowIndex < 8; rowIndex++) {
        for (int colIndex = 0; colIndex < 8; colIndex++) {
          decodedSound.add(blocks[blockIndex][rowIndex][colIndex]);
        }
      }
    }
  }

  void _writeDecodedSoundToFile(
      List<int> decodedSound, List<int> metaData, String  compressedSoundFilePath) {
    String fileName = compressedSoundFilePath.split("\\").last.split('.').first;
    if(fileName.contains("_compressed"))
      fileName = fileName.substring(0,fileName.length-11);
    File file = File("reconstructed_sound_file\\reconstructed_$fileName.wav");
    List<int> decodedSoundWithMetaData = [];
    decodedSoundWithMetaData.addAll(metaData);
    decodedSoundWithMetaData.addAll(decodedSound);
    file.writeAsBytes(decodedSoundWithMetaData);
  }
}
