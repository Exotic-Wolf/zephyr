import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zephyr_mobile/services/firebase_chat_service.dart';

void main() {
  test('chat image preparation outputs bounded JPEG upload file', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'zephyr-chat-media-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final img.Image source = img.Image(width: 1800, height: 1400);
    img.fill(source, color: img.ColorRgb8(240, 160, 80));
    final File sourceFile = File('${tempDir.path}/source.png');
    await sourceFile.writeAsBytes(img.encodePng(source));

    final PreparedChatImageUpload prepared = await prepareChatImageForUpload(
      sourceFile,
      outputDirectory: tempDir,
      maxBytes: 180 * 1024,
      maxEdge: 720,
    );

    final Uint8List uploadBytes = await prepared.file.readAsBytes();
    final img.Image? decoded = img.decodeImage(uploadBytes);

    expect(prepared.contentType, 'image/jpeg');
    expect(prepared.fileName, startsWith('chat_'));
    expect(prepared.fileName, endsWith('.jpg'));
    expect(prepared.byteSize, lessThanOrEqualTo(180 * 1024));
    expect(uploadBytes.length, prepared.byteSize);
    expect(decoded, isNotNull);
    expect(math.max(decoded!.width, decoded.height), lessThanOrEqualTo(720));
  });

  test('chat image preparation rejects non-image payloads', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'zephyr-chat-media-invalid-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final File sourceFile = File('${tempDir.path}/not-image.txt');
    await sourceFile.writeAsString('not an image');

    expect(
      prepareChatImageForUpload(sourceFile, outputDirectory: tempDir),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Unsupported image format'),
        ),
      ),
    );
  });
}
