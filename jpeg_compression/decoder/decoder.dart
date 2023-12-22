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
    print("size after runlength ${acCoefficientsWithRunLengthEncoding.length}");
    List<int> dpcmEncodedCoefficientsEncoding = _decodeHuffman(
        data["dpcmEncodedCoefficientsWithHuffman"], data["huffmanTable"]);

    print("dc size after huffman ${dpcmEncodedCoefficientsEncoding.length}");
    print (dpcmEncodedCoefficientsEncoding.last);
    List<int> quantizedDCCoefficients =
        _decodeDPCM(dpcmEncodedCoefficientsEncoding);
    List<int> runLengthDecodedACCoefficients =
        _decodeRunLengthEncoding(acCoefficientsWithRunLengthEncoding);
    print("AC size after runlength ${runLengthDecodedACCoefficients.length}");
    print("DC size after runlength ${quantizedDCCoefficients.length}");
    print("AC +DC size after runlength ${runLengthDecodedACCoefficients.length+quantizedDCCoefficients.length}");
     print("first ten numbers ${runLengthDecodedACCoefficients.sublist(0,100)}");
    List<List<List<int>>> blocks = [];
    _generateBlocks(
        quantizedDCCoefficients, runLengthDecodedACCoefficients, blocks);
    deQuantization(blocks, data["quantizationMatrix"]);
    _DCTCoefficientsReverse(blocks);
    _removeShift(blocks);
    List<int> decodedSound = [];
    _returnBlocksToList(blocks, decodedSound);
    _writeDecodedSoundToFile(decodedSound);

    //   print("first 10 numbers ${acCoefficientsWithRunLengthEncoding.sublist(0,10)}");
  }

  _getAllDataOfCompressedSoundFile(
      String filePath, Map<String, dynamic> data) async {
    // get data from file
    File file = File(filePath);
    String fileContent = await file.readAsString();
    Map<String, dynamic> fileContentAsMap = jsonDecode(fileContent);
    data["dpcmEncodedCoefficientsWithHuffman"] =
        List<int>.from(fileContentAsMap["dpcmEncodedCoefficientsWithHuffman"]);
    data["acCoefficientsWithHuffman"] =
        List<int>.from(fileContentAsMap["acCoefficientsWithHuffman"]);
    List<dynamic> temp =
        List<dynamic>.from(fileContentAsMap["quantizationMatrix"]);
    data["huffmanTableKeys"] =
        List<int>.from(fileContentAsMap["huffmanTableKeys"]);
    data["huffmanTableValues"] =
        List<String>.from(fileContentAsMap["huffmanTableValues"]);
    print (data["huffmanTableValues"]);
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
    print(huffmanTable);
    List<int> decodedData = [];
    String bitsRepresentation = "";
    int index = 0;
    while (index < encodedData.length) {
      for(int i=0;i<bitsRepresentation.length;i++)
        {//print(i);
          if(huffmanTable.containsKey(bitsRepresentation.substring(0,i)))
            {
              decodedData.add(huffmanTable[bitsRepresentation.substring(0,i)]);
             // print(bitsRepresentation.length);
              bitsRepresentation = bitsRepresentation.substring(i);
            //  print(bitsRepresentation.length);
              i=0;
            }
        }
        bitsRepresentation+= encodedData[index++].toRadixString(2).padLeft(8, '0');

      }
    for(int i=0;i<bitsRepresentation.length;i++)
    {//print(i);
      if(huffmanTable.containsKey(bitsRepresentation.substring(0,i)))
      {
        decodedData.add(huffmanTable[bitsRepresentation.substring(0,i)]);
        // print(bitsRepresentation.length);
        bitsRepresentation = bitsRepresentation.substring(i);
        //  print(bitsRepresentation.length);
        i=0;
      }
    }

    print("huffman decoding finished");
  //  print(decodedData.sublist(0, 10));
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
      } else if (acCoefficientsWithRunLengthEncoding[i] == (15<<4)) {
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
        try{
        decodedData.add(acCoefficientsWithRunLengthEncoding[i]);
        indexInsideBlock++;
        }
        catch(e){
          print(i-1);
          print(acCoefficientsWithRunLengthEncoding[i-1]);
        }
      }
    }
    return decodedData;
  }

  void _generateBlocks(List<int> quantizedDCCoefficients,
      List<int> runLengthDecodedACCoefficients, List<List<List<int>>> blocks) {
    print("quantizedDCCoefficients length is ${quantizedDCCoefficients.length}");
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
    //  print("block index is ${blocks[0]}");
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

  void _returnBlocksToList(List<List<List<int>>> blocks, List<int> decodedSound) {
    for (int blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      for (int rowIndex = 0; rowIndex < 8; rowIndex++) {
        for (int colIndex = 0; colIndex < 8; colIndex++) {
          decodedSound.add(blocks[blockIndex][rowIndex][colIndex]);
        }
      }
    }
  }

  void _writeDecodedSoundToFile(List<int> decodedSound) {
    print("decoded sound length is ${decodedSound.length}");
    File file = File("decoded_sound.wav");
    file.writeAsBytes(decodedSound);
  }
}
/*
huffman table is {-1: 0, 2: 4, -2: 5, 81: 6, 225: 1792, 241: 7172, 240: 7173, 209: 3587, 193: 897, 177: 449, 161: 225, 145: 113, 129: 57, 113: 29, 97: 15, 65: 2, 49: 3, 0: 2, 33: 3, 17: 1, 1: 1}
*/
