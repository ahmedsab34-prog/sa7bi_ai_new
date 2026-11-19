import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _requiredBodyAnimations = <String>{
  'Hero_Idle',
  'Hero_Welcome',
  'Hero_Power',
};

const _requiredExpressionClips = <String>{
  'HERO_FACE_SMILE',
  'HERO_FACE_SAD',
  'HERO_FACE_SURPRISE',
  'HERO_FACE_ANGRY',
  'HERO_FACE_WINK',
  'HERO_FACE_BLINK',
};

const _requiredVisemeClips = <String>{
  'HERO_VISEME_sil',
  'HERO_VISEME_PP',
  'HERO_VISEME_FF',
  'HERO_VISEME_TH',
  'HERO_VISEME_DD',
  'HERO_VISEME_kk',
  'HERO_VISEME_CH',
  'HERO_VISEME_SS',
  'HERO_VISEME_nn',
  'HERO_VISEME_RR',
  'HERO_VISEME_aa',
  'HERO_VISEME_E',
  'HERO_VISEME_I',
  'HERO_VISEME_O',
  'HERO_VISEME_U',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sa7bi HERO GLB contains original body clips and the complete face rig',
      () async {
    final data = await rootBundle.load('assets/3d/sa7bi_hero.glb');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    expect(bytes.length, greaterThan(100000));

    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(0, Endian.little), 0x46546C67);
    expect(header.getUint32(4, Endian.little), 2);
    expect(header.getUint32(8, Endian.little), bytes.length);

    String? jsonChunk;
    Uint8List? binaryChunk;
    var offset = 12;

    while (offset + 8 <= bytes.length) {
      final chunkHeader = ByteData.sublistView(
        bytes,
        offset,
        offset + 8,
      );
      final chunkLength = chunkHeader.getUint32(0, Endian.little);
      final chunkType = chunkHeader.getUint32(4, Endian.little);
      offset += 8;

      if (chunkLength > bytes.length - offset) {
        fail('Invalid GLB chunk length.');
      }

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
    final buffers = _maps(gltf['buffers']);
    expect(buffers, isNotEmpty);
    final bufferLength = buffers.first['byteLength'] as int;
    expect(binaryChunk!.length, greaterThanOrEqualTo(bufferLength));

    for (final view in _maps(gltf['bufferViews'])) {
      final viewOffset = (view['byteOffset'] as int?) ?? 0;
      final viewLength = view['byteLength'] as int;
      expect(viewOffset + viewLength, lessThanOrEqualTo(bufferLength));
    }

    final animationEntries = _maps(gltf['animations']);
    final animationNames = animationEntries
        .map((item) => _string(item['name']))
        .where((name) => name.isNotEmpty)
        .toSet();

    expect(animationNames, containsAll(_requiredBodyAnimations));
    expect(
      animationNames,
      containsAll(_requiredExpressionClips),
      reason: 'The production GLB must include all six facial expressions.',
    );
    expect(
      animationNames,
      containsAll(_requiredVisemeClips),
      reason: 'The production GLB must include all fifteen viseme clips.',
    );

    final targetNames = <String>[];
    var morphTargetCount = 0;
    for (final mesh in _maps(gltf['meshes'])) {
      final extras = _map(mesh['extras']);
      final names = extras?['targetNames'];
      if (names is List) {
        targetNames.addAll(names.whereType<String>());
      }
      for (final primitive in _maps(mesh['primitives'])) {
        morphTargetCount += _maps(primitive['targets']).length;
      }
    }

    expect(morphTargetCount, 21);
    expect(
      targetNames.toSet(),
      containsAll({..._requiredExpressionClips, ..._requiredVisemeClips}),
    );

    final nodeNames = _maps(gltf['nodes'])
        .map((node) => _string(node['name']))
        .where((name) => name.isNotEmpty)
        .toSet();
    expect(
      nodeNames,
      containsAll({
        'HeroMouthRoot',
        'HeroMouthCavity',
        'HeroMouthTeeth',
        'HeroMouthTongue',
      }),
    );

    final nodes = _maps(gltf['nodes']);
    final mouthNodeIndex = nodes.indexWhere(
      (node) => node['name'] == 'HeroMouthCavity',
    );
    expect(mouthNodeIndex, greaterThanOrEqualTo(0));

    final accessors = _maps(gltf['accessors']);
    for (final visemeName in _requiredVisemeClips) {
      final clip = animationEntries.singleWhere(
        (item) => item['name'] == visemeName,
      );
      final samplers = _maps(clip['samplers']);
      final channels = _maps(clip['channels']);
      final hasMouthWeights = channels.any((channel) {
        final target = _map(channel['target']);
        return target?['node'] == mouthNodeIndex &&
            target?['path'] == 'weights';
      });
      expect(hasMouthWeights, isTrue, reason: '$visemeName must animate mouth weights.');

      for (final channel in channels) {
        final samplerIndex = channel['sampler'] as int;
        final sampler = samplers[samplerIndex];
        final input = accessors[sampler['input'] as int];
        final output = accessors[sampler['output'] as int];
        final target = _map(channel['target']);
        if (target?['node'] == mouthNodeIndex && target?['path'] == 'weights') {
          expect(output['type'], 'SCALAR');
          expect(
            output['count'],
            (input['count'] as int) * 21,
            reason: '$visemeName must provide all 21 morph weights per keyframe.',
          );
        }
      }
    }

    // Verify the existing embedded Sa7bi chest-logo PNG was preserved.
    final images = _maps(gltf['images']);
    expect(images, hasLength(1));
    final bufferViewIndex = images.single['bufferView'];
    expect(bufferViewIndex, isA<int>());
    final bufferViews = _maps(gltf['bufferViews']);
    final bufferView = bufferViews[bufferViewIndex as int];
    final imageOffset = (bufferView['byteOffset'] as int?) ?? 0;
    final imageLength = bufferView['byteLength'] as int;
    final embeddedImage = binaryChunk.sublist(
      imageOffset,
      imageOffset + imageLength,
    );
    expect(
      embeddedImage.take(8).toList(),
      [137, 80, 78, 71, 13, 10, 26, 10],
    );

    print('SA7BI_HERO_BODY_ANIMATIONS=${_requiredBodyAnimations.length}');
    print('SA7BI_HERO_FACE_EXPRESSIONS=${_requiredExpressionClips.length}');
    print('SA7BI_HERO_VISEMES=${_requiredVisemeClips.length}');
    print('SA7BI_HERO_MORPH_TARGETS=$morphTargetCount');
    print('SA7BI_HERO_FACE_RIG=AVAILABLE');
  });
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _string(dynamic value) => value is String ? value : '';
