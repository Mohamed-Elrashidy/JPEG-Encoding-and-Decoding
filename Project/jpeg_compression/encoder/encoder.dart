import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../huffman_tree_node.dart';
import '../sound_file.dart';

class Encoder {
  Encoder({required this.filePath});
  String filePath;
  encode() async {
    List<List<List<int>>> blocks =
        await SoundFile(filePath: filePath).getListOfBlocks();
    List<int> metaData = await SoundFile(filePath: filePath).getMetaData();
    //shift block
    List<List<List<int>>> shiftedBlocks = _shiftLeft(blocks);
    // DCT and quantization
    List<List<List<int>>> dctCoefficients = _dctCoefficients(shiftedBlocks);
    List<List<int>> quantizationMatrix = _getQuantizationMatrix();
    List<List<List<int>>> quantizedDCTCoefficients =
        _quantizeDCTCoefficients(dctCoefficients, quantizationMatrix);
    // run length encoding
    List<List<int>> zigzagOrder = _zigzagOrder(quantizedDCTCoefficients);
    List<int> runLengthEncodedCoefficients = _runLengthEncoding(zigzagOrder);
    // DC Encoding Coefficients
    List<int> DPCMEncodedCoefficients = _DPCMEncoding(quantizedDCTCoefficients);
    // huffman encoding
    Map<int, String> huffmanTable =
        _getHuffmanTable(runLengthEncodedCoefficients, DPCMEncodedCoefficients);
    List<int> DPCMEncodedCoefficientsWithHuffman = [];
    _applyHuffmanEncoding(DPCMEncodedCoefficients, huffmanTable,
        DPCMEncodedCoefficientsWithHuffman);
    List<int> ACCoefficientsWithHuffman = [];
    _applyHuffmanEncoding(
        runLengthEncodedCoefficients, huffmanTable, ACCoefficientsWithHuffman);

    _writeAtFile(DPCMEncodedCoefficientsWithHuffman, ACCoefficientsWithHuffman,
        huffmanTable, quantizationMatrix,metaData,filePath);
  }

  // subtract 2^(n-1) from each element in the block in this case 128
  List<List<List<int>>> _shiftLeft(List<List<List<int>>> blocks) {
    int shiftValue = 128;
    List<List<List<int>>> shiftedBlocks = [];
    for (int i = 0; i < blocks.length; i++) {
      List<List<int>> shiftedBlock = [];
      for (int j = 0; j < blocks[i].length; j++) {
        List<int> shiftedRow = [];
        for (int k = 0; k < blocks[i][j].length; k++) {
          shiftedRow.add(blocks[i][j][k] - shiftValue);
        }
        shiftedBlock.add(shiftedRow);
      }
      shiftedBlocks.add(shiftedBlock);
    }
    return shiftedBlocks;
  }

  _dctCoefficients(List<List<List<int>>> blocks) {
    List<List<List<int>>> dctCoefficients = [];
    for (int i = 0; i < blocks.length; i++) {
      dctCoefficients.add(_blockDCTCoefficientCalculation(blocks[i]));
    }
    return blocks;
  }

  _blockDCTCoefficientCalculation(List<List<int>> block) {
    List<List<int>> dctCoefficients = [];
    for (int rowIndex = 0; rowIndex < block.length; rowIndex++) {
      List<int> dctRow = [];
      for (int colIndex = 0; colIndex < block[0].length; colIndex++) {
        double coefficientValue = 0;
        for (int x = 0; x < block.length; x++) {
          for (int y = 0; y < block[0].length; y++) {
            coefficientValue += (block[x][y] *
                cos(((2 * x + 1) * rowIndex * pi) / 16) *
                cos(((2 * y + 1) * colIndex * pi) / 16));
          }
        }
        coefficientValue = coefficientValue / 4;

        if (rowIndex == 0 && colIndex == 0) {
          coefficientValue /= sqrt(2);
        }
        dctRow.add(coefficientValue.floor());
      }
      dctCoefficients.add(dctRow);
    }
    return dctCoefficients;
  }

  List<List<int>> _getQuantizationMatrix() {
    List<List<int>> quantizationMatrix = List.filled(8, List.filled(8, 0));
    int quality = 0;
    for (int i = 0; i < 8; i++) {
      for (int f = 0; f < 8; f++) {
        quantizationMatrix[i][f] = ((1 + (1 + i + f) * quality));
      }
    }
    return quantizationMatrix;
  }

  List<List<List<int>>> _quantizeDCTCoefficients(
      List<List<List<int>>> dctCoefficients,
      List<List<int>> quantizationMatrix) {
    List<List<List<int>>> quantizedDCTCoefficientsBlocks = [];
    for (int i = 0; i < dctCoefficients.length; i++) {
      List<List<int>> quantizedDCTCoefficientBlock = [];
      for (int j = 0; j < dctCoefficients[i].length; j++) {
        List<int> quantizedDCTRow = [];
        for (int k = 0; k < dctCoefficients[i][j].length; k++) {
          quantizedDCTRow.add(
              (dctCoefficients[i][j][k] / quantizationMatrix[j][k]).floor());
        }
        quantizedDCTCoefficientBlock.add(quantizedDCTRow);
      }
      quantizedDCTCoefficientsBlocks.add(quantizedDCTCoefficientBlock);
    }
    return quantizedDCTCoefficientsBlocks;
  }

  List<int> _runLengthEncoding(List<List<int>> blocksZigZagOrder) {
    List<int> runLengthEncodedCoefficients = [];
    for (int blockIndex = 0;
        blockIndex < blocksZigZagOrder.length;
        blockIndex++) {
      List<int> zigzagOrder = blocksZigZagOrder[blockIndex];
      _runLengthEncodingBlock(zigzagOrder, runLengthEncodedCoefficients);
    }
    return runLengthEncodedCoefficients;
  }

  List<List<int>> _zigzagOrder(List<List<List<int>>> quantizedDCTCoefficient) {
    int numRows = quantizedDCTCoefficient[0].length;
    int numCols = quantizedDCTCoefficient[0][0].length;
    List<List<int>> result = [];
    for (int blockIndex = 0;
        blockIndex < quantizedDCTCoefficient.length;
        blockIndex++) {
      List<int> zigzagOrder = [];
      for (int sum = 1; sum <= numRows + numCols - 2; sum++) {
        if (sum % 2 == 0) {
          // Even sum, move up
          for (int row = sum; row >= 0; row--) {
            int col = sum - row;
            if (row < numRows && col < numCols) {
              zigzagOrder.add(quantizedDCTCoefficient[blockIndex][row][col]);
            }
          }
        } else {
          // Odd sum, move down
          for (int col = sum; col >= 0; col--) {
            int row = sum - col;
            if (row < numRows && col < numCols) {
              zigzagOrder.add(quantizedDCTCoefficient[blockIndex][row][col]);
            }
          }
        }
      }
      result.add(zigzagOrder);
    }
    return result;
  }

  _runLengthEncodingBlock(List<int> zigzagOrder, List<int> result) {
    int zeroCounter = 0;
    for (int i = 0; i < zigzagOrder.length; i++) {
      if (zigzagOrder[i] == 0) {
        zeroCounter++;
      } else {
        while (zeroCounter > 15) {
          result.add((15 << 4));// 11110000
          zeroCounter -= 16;
        }
        result.add((zeroCounter << 4) | zigzagOrder[i].bitLength);
        result.add(zigzagOrder[i]);
        zeroCounter = 0;
      }
    }
    result.add(0);
  }

  List<int> _DPCMEncoding(List<List<List<int>>> quantizedDCTCoefficients) {
    List<int> DPCMEncodedCoefficients = [];
    int previousDC = 0;
    for (int blockIndex = 0;
        blockIndex < quantizedDCTCoefficients.length;
        blockIndex++) {
      int currentDC = quantizedDCTCoefficients[blockIndex][0][0];
      int encodedDC = currentDC - previousDC;
      DPCMEncodedCoefficients.add(encodedDC);
      previousDC = currentDC;
    }
    return DPCMEncodedCoefficients;
  }

  _getHuffmanTable(List<int> runLengthEncodedCoefficients,
      List<int> dpcmEncodedCoefficients) {

    Map<int, String> huffmanTable = {};
    Map<int, int> statics = {};
    for (int i = 0; i < runLengthEncodedCoefficients.length; i++) {
      statics.putIfAbsent(runLengthEncodedCoefficients[i], () => 0);
      statics[runLengthEncodedCoefficients[i]] =
          statics[runLengthEncodedCoefficients[i]]! + 1;
    }
    for (int i = 0; i < dpcmEncodedCoefficients.length; i++) {
      statics.putIfAbsent(dpcmEncodedCoefficients[i], () => 0);
      statics[dpcmEncodedCoefficients[i]] =
          statics[dpcmEncodedCoefficients[i]]! + 1;
    }
    _createHuffmanTable(statics, huffmanTable);
    return huffmanTable;
  }

  _createHuffmanTable(Map<int, int> statics, Map<int, String> huffmanTable) {

    HuffmanTreeNode treeRoot = _createHuffmanTree(statics);
    String code= "";
    if(statics.length==1)
      code ="1";
    _createHuffmanTableHelper(treeRoot, huffmanTable, code);
    return huffmanTable;
  }

  HuffmanTreeNode _createHuffmanTree(Map<int, int> statics) {
    List<int> keys = statics.keys.toList();
    keys.sort((a, b) => statics[a]!.compareTo(statics[b]!));
    List<HuffmanTreeNode> nodes = [];
    for (int i = 0; i < keys.length; i++) {
      nodes.add(
          HuffmanTreeNode(value: keys[i], childrenCount: statics[keys[i]]!));
    }
    while (nodes.length > 1) {
      HuffmanTreeNode left = nodes.removeAt(0);
      HuffmanTreeNode right = nodes.removeAt(0);
      HuffmanTreeNode parent = HuffmanTreeNode(
          childrenCount: left.childrenCount + right.childrenCount,
          left: left,
          right: right);
      nodes.add(parent);
      nodes.sort((a, b) => a.childrenCount.compareTo(b.childrenCount));
    }
    return nodes[0];
  }

  _createHuffmanTableHelper(
      HuffmanTreeNode treeRoot, Map<int, String> huffmanTable, String code) {
    if (treeRoot.left == null && treeRoot.right == null) {
      huffmanTable[treeRoot.value!] = code;
      return;
    }
    _createHuffmanTableHelper(treeRoot.left!, huffmanTable,code+ '0' );
    _createHuffmanTableHelper(treeRoot.right!, huffmanTable, code + '1'  );
  }

  _applyHuffmanEncoding(
      List<int> originalData, Map<int, String> huffmanTable, List<int> result) {
    String bitsRepresentation = "";
    for (int i = 0; i < originalData.length; i++) {
      bitsRepresentation += huffmanTable[originalData[i]]!;
      while (bitsRepresentation.length >= 8) {
        int temp = int.parse(bitsRepresentation.substring(0, 8), radix: 2);
        result.add(temp);

        bitsRepresentation = bitsRepresentation.substring(8);
      }
    }
    if(bitsRepresentation.isNotEmpty)
      {
        while(bitsRepresentation.length<8)
          bitsRepresentation+='0';
        int temp = int.parse(bitsRepresentation, radix: 2);
        result.add(temp);
      }
  }

  _writeAtFile(
      List<int> dpcmEncodedCoefficientsWithHuffman,
      List<int> acCoefficientsWithHuffman,
      Map<int, String> huffmanTable,
      List<List<int>> quantizationMatrix,List<int> metaData,String originalFilePath) async {
    List<String> huffmanTableValues = [];
    huffmanTable.values.toList().forEach((element) {
      huffmanTableValues.add('"$element"');
    });
    Map<String, dynamic> encodedData = {
      '"dpcmEncodedCoefficientsWithHuffman"':
          Uint8List.fromList(dpcmEncodedCoefficientsWithHuffman),
      '"acCoefficientsWithHuffman"':
          Uint8List.fromList(acCoefficientsWithHuffman),
      '"huffmanTableKeys"': huffmanTable.keys.toList(),
      '"huffmanTableValues"': huffmanTableValues,
      '"quantizationMatrix"': quantizationMatrix,
      '"metaData"':metaData
    };
    String originalFileName = originalFilePath.split("\\").last.split(".").first;
    print("original file name is $originalFileName");
    String compressedFilePath="compressed_sound_files\\${originalFileName}_compressed.bin";
    compressToFile(encodedData,compressedFilePath);

  }
  Future<void> compressToFile(
      Map<String, dynamic> data,
      String filename) async {
    final encodedDataBytes = utf8.encode(data.toString());

    // Compress the data using ZLib with the specified compression level
    final compressedData = ZLibCodec(level: 9).encode(encodedDataBytes);

    final file = File(filename);
    await file.writeAsBytes(compressedData);
    print('Compression completed. File saved: $filename');
  }
}
