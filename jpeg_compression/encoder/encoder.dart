import 'dart:math';

import '../sound_file.dart';

class Encoder {
  Encoder({required this.filePath});
  String filePath;
  encode() async {
    List<List<List<int>>> blocks =
        await SoundFile(filePath: filePath).getListOfBlocks();
    List<List<List<int>>> shiftedBlocks = _shiftLeft(blocks);
    List<List<List<int>>> dctCoefficients = _dctCoefficients(shiftedBlocks);
    List<List<int>> quantizationMatrix = _getQuantizationMatrix();
    List<List<List<int>>> quantizedDCTCoefficients =
        _quantizeDCTCoefficients(dctCoefficients, quantizationMatrix);

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
                cos(((2 * y + 1) * colIndex * pi) / 16)) as int;
          }
        }
        coefficientValue = coefficientValue / 4;

        if (rowIndex == 0 && colIndex == 0) {
          coefficientValue /= sqrt(2);
        }
        dctRow.add(coefficientValue.round());
      }
      dctCoefficients.add(dctRow);
    }
    return dctCoefficients;
  }

  List<List<int>> _getQuantizationMatrix() {
    List<List<int>>quantizationMatrix=List.filled(8, List.filled(8, 0));
    int quality=15;
    for(int i=0;i<8;i++)
      {
        for(int f=0;f<8;f++)
          {
            quantizationMatrix[i][f]=((1+(1+i+f)*quality));
          }
      }
    return quantizationMatrix;
  }

  List<List<List<int>>> _quantizeDCTCoefficients(List<List<List<int>>> dctCoefficients, List<List<int>> quantizationMatrix) {
    List<List<List<int>>> quantizedDCTCoefficientsBlocks = [];
    for (int i = 0; i < dctCoefficients.length; i++) {
      List<List<int>> quantizedDCTCoefficientBlock = [];
      for (int j = 0; j < dctCoefficients[i].length; j++) {
        List<int> quantizedDCTRow = [];
        for (int k = 0; k < dctCoefficients[i][j].length; k++) {
          quantizedDCTRow.add((dctCoefficients[i][j][k] / quantizationMatrix[j][k]).round());
        }
        quantizedDCTCoefficientBlock.add(quantizedDCTRow);
      }
      quantizedDCTCoefficientsBlocks.add(quantizedDCTCoefficientBlock);
    }
    return quantizedDCTCoefficientsBlocks;
  }





}
