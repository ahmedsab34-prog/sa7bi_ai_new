import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sa7bi HERO GLB contains the app-logo texture and named animations',
      () async {
    final data = await rootBundle.load('assets/3d/sa7bi_hero.glb');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    expect(bytes.length, greaterThan(100000));

    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(0, Endian.little), 0x46546C67);
    expect(header.getUint32(4, Endian.little), 2);
    expect(header.getUint32(8, Endian.little), bytes.length);

    var offset = 12;
    String? jsonChunk;
    Uint8List? binaryChunk;

    while (offset + 8 <= bytes.length) {
      final chunkHeader = ByteData.sublistView(bytes, offset, offset + 8);
      final chunkLength = chunkHeader.getUint32(0, Endian.little);
      final chunkType = chunkHeader.getUint32(4, Endian.little);
      offset += 8;
      expect(offset + chunkLength, lessThanOrEqualTo(bytes.length));

      if (chunkType == 0x4E4F534A) {
        jsonChunk = utf8.decode(bytes.sublist(offset, offset + chunkLength));
      } else if (chunkType == 0x004E4942) {
        binaryChunk = bytes.sublist(offset, offset + chunkLength);
      }
      offset += chunkLength;
    }

    expect(jsonChunk, isNotNull);
    expect(binaryChunk, isNotNull);
    final gltf = jsonDecode(jsonChunk!) as Map<String, dynamic>;

    final animationNames = (gltf['animations'] as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['name'])
        .toSet();
    expect(animationNames, containsAll(<String>{
      'Hero_Idle',
      'Hero_Welcome',
      'Hero_Power',
    }));

    final image = (gltf['images'] as List<dynamic>).single
        as Map<String, dynamic>;
    final bufferViewIndex = image['bufferView'] as int;
    final bufferView = (gltf['bufferViews'] as List<dynamic>)[bufferViewIndex]
        as Map<String, dynamic>;
    final imageOffset = (bufferView['byteOffset'] as int?) ?? 0;
    final imageLength = bufferView['byteLength'] as int;
    final embeddedImage = binaryChunk!.sublist(
      imageOffset,
      imageOffset + imageLength,
    );

    // Embedded PNG signature: the exact app icon is stored in the GLB texture.
    expect(embeddedImage.take(8).toList(), <int>[
      137, 80, 78, 71, 13, 10, 26, 10,
    ]);
    expect((gltf['materials'] as List<dynamic>).isNotEmpty, isTrue);
  });
}
