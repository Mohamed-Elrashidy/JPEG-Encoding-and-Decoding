import 'dart:io';

import 'decoder/decoder.dart';
import 'encoder/encoder.dart';

Future<void> main (List<String>args) async {
  print("Select the number of operation you want to do \n 1- Encode \n 2- Decode \n");
  int operation = int.parse(stdin.readLineSync()!);
  if(operation == 1){
    print("Enter the path of the sound file you want to encode");
    String filePath = stdin.readLineSync()!;
    Encoder(filePath: filePath).encode();
  }
  else if(operation == 2){
    print("Enter the path of the Compressed sound file you want to decode");
    String filePath = stdin.readLineSync()!;
    await Decoder(filePath:filePath).decode();
  }
  else{
    print("Invalid operation");
  }

}
