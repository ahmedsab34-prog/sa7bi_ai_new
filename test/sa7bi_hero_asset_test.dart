import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Sa7bi HERO: validate model, logo, animations and facial rig',
    () async {
      final data = await rootBundle.load(
        'assets/3d/sa7bi_hero.glb',
      );

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      expect(bytes.length, greaterThan(100000));

      final header = ByteData.sublistView(bytes);

      expect(
        header.getUint32(0, Endian.little),
        0x46546C67,
      );

      expect(
        header.getUint32(4, Endian.little),
        2,
      );

      expect(
        header.getUint32(8, Endian.little),
        bytes.length,
      );

      String? jsonChunk;
      Uint8List? binaryChunk;

      var offset = 12;

      while (offset + 8 <= bytes.length) {
        final chunkHeader = ByteData.sublistView(
          bytes,
          offset,
          offset + 8,
        );

        final chunkLength = chunkHeader.getUint32(
          0,
          Endian.little,
        );

        final chunkType = chunkHeader.getUint32(
          4,
          Endian.little,
        );

        offset += 8;

        if (chunkLength > bytes.length - offset) {
          fail('Invalid GLB chunk length.');
        }

        if (chunkType == 0x4E4F534A) {
          jsonChunk = utf8.decode(
            bytes.sublist(
              offset,
              offset + chunkLength,
            ),
          );
        } else if (chunkType == 0x004E4942) {
          binaryChunk = bytes.sublist(
            offset,
            offset + chunkLength,
          );
        }

        offset += chunkLength;
      }

      expect(jsonChunk, isNotNull);
      expect(binaryChunk, isNotNull);

      final gltf = jsonDecode(jsonChunk!)
          as Map<String, dynamic>;

      final animationNames = _maps(gltf['animations'])
          .map((item) => _string(item['name']))
          .where((name) => name.isNotEmpty)
          .toSet();

      expect(
        animationNames,
        containsAll({
          'Hero_Idle',
          'Hero_Welcome',
          'Hero_Power',
        }),
      );

      // Verify the original Sa7bi logo texture.
      final images = _maps(gltf['images']);

      expect(images, hasLength(1));

      final image = images.single;

      final bufferViewIndex = image['bufferView'];

      expect(bufferViewIndex, isA<int>());

      final bufferViews = _maps(gltf['bufferViews']);

      final bufferView = bufferViews[bufferViewIndex as int];

      final imageOffset =
          (bufferView['byteOffset'] as int?) ?? 0;

      final imageLength =
          bufferView['byteLength'] as int;

      final embeddedImage = binaryChunk!.sublist(
        imageOffset,
        imageOffset + imageLength,
      );

      expect(
        embeddedImage.take(8).toList(),
        [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ],
      );

      // Detect facial morph targets.
      final meshes = _maps(gltf['meshes']);

      var morphTargetCount = 0;

      final morphTargetNames = <String>[];

      for (final mesh in meshes) {
        final primitives = _maps(mesh['primitives']);

        for (final primitive in primitives) {
          final targets = _maps(primitive['targets']);

          morphTargetCount += targets.length;
        }

        final extras = _map(mesh['extras']);

        final names = extras?['targetNames'];

        if (names is List) {
          morphTargetNames.addAll(
            names.whereType<String>(),
          );
        }
      }

      // Detect facial bones in the model skeleton.
      final nodes = _maps(gltf['nodes']);
      final skins = _maps(gltf['skins']);

      final facePattern = RegExp(
        r'face|head|jaw|mouth|lip|eye|eyelid|brow|blink|smile',
        caseSensitive: false,
      );

      final faceNodeNames = nodes
          .map((node) => _string(node['name']))
          .where((name) => facePattern.hasMatch(name))
          .toSet();

      final jointNames = <String>[];

      for (final skin in skins) {
        final joints = skin['joints'];

        if (joints is! List) continue;

        for (final rawIndex in joints) {
          if (rawIndex is! int) continue;

          if (rawIndex < 0 || rawIndex >= nodes.length) {
            continue;
          }

          final name = _string(nodes[rawIndex]['name']);

          if (name.isNotEmpty && facePattern.hasMatch(name)) {
            jointNames.add(name);
          }
        }
      }

      // Detect facial animations.
      final facialAnimationNames = animationNames
          .where((name) => facePattern.hasMatch(name))
          .toList();

      final hasFacialRig =
          morphTargetCount > 0 ||
          jointNames.isNotEmpty ||
          facialAnimationNames.isNotEmpty;

      print('======================================');
      print('SA7BI HERO MODEL DIAGNOSTICS');
      print('======================================');

      print('Model size: ${bytes.length} bytes');

      print('Body animations:');
      for (final name in animationNames) {
        print(' - $name');
      }

      print('Morph targets: $morphTargetCount');

      print('Morph target names:');
      for (final name in morphTargetNames) {
        print(' - $name');
      }

      print('Facial bones:');
      for (final name in jointNames.toSet()) {
        print(' - $name');
      }

      print('Facial nodes:');
      for (final name in faceNodeNames) {
        print(' - $name');
      }

      print('Facial animations:');
      for (final name in facialAnimationNames) {
        print(' - $name');
      }

      print(
        hasFacialRig
            ? 'SA7BI_HERO_FACE_RIG=AVAILABLE'
            : 'SA7BI_HERO_FACE_RIG=NOT_FOUND',
      );

      print('======================================');

      // No failure when the face rig is absent:
      // the report determines whether we can animate this model
      // directly or whether facial rigging is required.
    },
  );
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];

  return value
      .whereType<Map>()
      .map(
        (item) => Map<String, dynamic>.from(item),
      )
      .toList(growable: false);
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return null;
}

String _string(dynamic value) {
  return value is String ? value : '';
}
