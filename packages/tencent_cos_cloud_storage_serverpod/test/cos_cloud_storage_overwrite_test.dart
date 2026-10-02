import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serverpod/serverpod.dart';
import 'package:tencent_cos_cloud_storage_serverpod/tencent_cos_cloud_storage_serverpod.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

class _SessionFake extends Fake implements Session {}

void main() {
  late CosCloudStorage storage;

  setUp(() {
    storage = CosCloudStorage.test(
      storageId: 'public',
      public: true,
      bucket: 'example-bucket',
      region: 'ap-guangzhou',
      secretId: 'test-secret-id',
      secretKey: 'test-secret-key',
    );
  });

  test('mixes in CloudStorageWithOptions', () {
    expect(storage, isA<CloudStorageWithOptions>());
  });

  test(
    'preventOverwrite true and existing object throws without PUT',
    () async {
      final methods = await _record(() async {
        await expectLater(
          storage.storeFileWithOptions(
            session: _SessionFake(),
            path: 'folder/file.txt',
            byteData: ByteData(4),
            options: const CloudStorageOptions(preventOverwrite: true),
          ),
          throwsA(
            isA<CloudStorageException>().having(
              (error) => error.message,
              'message',
              contains('preventOverwrite'),
            ),
          ),
        );
      });

      expect(methods, isNot(contains('PUT')));
    },
  );

  test('preventOverwrite false still puts when object exists', () async {
    final methods = await _record(() async {
      await storage.storeFileWithOptions(
        session: _SessionFake(),
        path: 'folder/file.txt',
        byteData: ByteData(4),
        options: const CloudStorageOptions(preventOverwrite: false),
      );
    });

    expect(methods, contains('PUT'));
  });

  test('preventOverwrite true still puts when object is absent', () async {
    final methods = await _record(() async {
      await storage.storeFileWithOptions(
        session: _SessionFake(),
        path: 'folder/file.txt',
        byteData: ByteData(4),
        options: const CloudStorageOptions(preventOverwrite: true),
      );
    }, headStatus: 404);

    expect(methods, contains('PUT'));
  });

  for (final status in [403, 500]) {
    test(
      'preventOverwrite true and HEAD $status throws without PUT',
      () async {
        final methods = await _record(() async {
          await expectLater(
            storage.storeFileWithOptions(
              session: _SessionFake(),
              path: 'folder/file.txt',
              byteData: ByteData(4),
              options: const CloudStorageOptions(preventOverwrite: true),
            ),
            throwsA(isA<CloudStorageException>()),
          );
        }, headStatus: status);

        expect(methods, ['HEAD']);
      },
    );

    test(
      'preventOverwrite true and HEAD $status does not sign upload',
      () async {
        final methods = await _record(() async {
          await expectLater(
            storage.createDirectFileUploadDescriptionWithOptions(
              session: _SessionFake(),
              path: 'folder/file.txt',
              options: const CloudStorageOptions(preventOverwrite: true),
            ),
            throwsA(isA<CloudStorageException>()),
          );
        }, headStatus: status);

        expect(methods, ['HEAD']);
      },
    );
  }

  test('storeFile without options replaces the same path', () async {
    final methods = await _record(() async {
      await storage.storeFile(
        session: _SessionFake(),
        path: 'folder/file.txt',
        byteData: ByteData(4),
      );
    });

    expect(methods, ['PUT']);
  });

  test(
    'preventOverwrite true and existing object does not sign upload',
    () async {
      final methods = await _record(() async {
        await expectLater(
          storage.createDirectFileUploadDescriptionWithOptions(
            session: _SessionFake(),
            path: 'folder/file.txt',
            options: const CloudStorageOptions(preventOverwrite: true),
          ),
          throwsA(
            isA<CloudStorageException>().having(
              (error) => error.message,
              'message',
              contains('preventOverwrite'),
            ),
          ),
        );
      });

      expect(methods, ['HEAD']);
    },
  );

  test(
    'preventOverwrite false keeps the existing upload signing path',
    () async {
      final methods = await _record(() async {
        await expectLater(
          storage.createDirectFileUploadDescriptionWithOptions(
            session: _SessionFake(),
            path: 'folder/file.txt',
            options: const CloudStorageOptions(preventOverwrite: false),
          ),
          throwsA(isNot(isA<CloudStorageException>())),
        );
      });

      expect(methods, isEmpty);
    },
  );
}

/// 在 mock 客户端里记下真正发出的方法。对象已存在时 HEAD 返回 [headStatus]。
Future<List<String>> _record(
  Future<void> Function() body, {
  int headStatus = 200,
}) async {
  final methods = <String>[];
  final mock = MockClient((request) async {
    methods.add(request.method);
    final status = request.method == 'HEAD' ? headStatus : 204;
    return http.Response('', status);
  });
  await http.runWithClient(body, () => mock);
  return methods;
}
