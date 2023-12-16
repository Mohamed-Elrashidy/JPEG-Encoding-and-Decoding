import 'dart:io';

import 'encoder/encoder.dart';
import 'sound_file.dart';

Future<void> main (List<String>args) async {
  String filePath = "E:/Fourth year/First semster/multimedia/project/JPEG-Encoding-and-Decoding/original_sound_files/test_ringtone.wav";
  SoundFile soundFile = SoundFile(filePath: filePath);
  // get matrix of non-overlapping 8*8 blocks
 Encoder(filePath: filePath).encode();
}