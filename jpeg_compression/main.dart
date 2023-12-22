import 'dart:io';

import 'decoder/decoder.dart';
import 'encoder/encoder.dart';
import 'sound_file.dart';

Future<void> main (List<String>args) async {
  String filePath = "E:/Fourth year/First semster/multimedia/project/JPEG-Encoding-and-Decoding/original_sound_files/test_ringtone.wav";
  SoundFile soundFile = SoundFile(filePath: filePath);
  // get matrix of non-overlapping 8*8 blocks
 await Decoder(filePath:"file.txt").decode();
 //Encoder(filePath: filePath).encode();
}
/*
*blocks is 7375040
blocks is 115235
ziajag order length is 7259805
dpcm coding length is 115235
ziagzag or der + dpcm 7375040
run length coding length is 9227197
dpcm coding length is 115235
* */