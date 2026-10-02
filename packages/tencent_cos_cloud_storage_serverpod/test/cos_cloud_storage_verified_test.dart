import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serverpod/serverpod.dart';
import 'package:tencent_cos_cloud_storage_serverpod/src/cos_upload_gate.dart';
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

  test('storeFile uploads only the ByteData view', () async {
    final raw = Uint8List.fromList([9, 9, 1, 2, 3, 4]);
    final view = ByteData.sublistView(raw, 2);
    Uint8List? sent;
    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        sent = Uint8List.fromList(request.bodyBytes);
      }
      return http.Response('', 204);
    });

    await http.runWithClient(() async {
      await storage.storeFile(
        session: _SessionFake(),
        path: 'folder/file.txt',
        byteData: view,
      );
    }, () => mock);

    expect(sent, Uint8List.fromList([1, 2, 3, 4]));
  });

  test('blank secret key is a config error', () {
    expect(
      () => CosCloudStorage.test(
        storageId: 'public',
        public: true,
        bucket: 'example-bucket',
        region: 'ap-guangzhou',
        secretId: 'test-secret-id',
        secretKey: '   ',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('blank secret id is a config error', () {
    expect(
      () => CosCloudStorage.test(
        storageId: 'public',
        public: true,
        bucket: 'example-bucket',
        region: 'ap-guangzhou',
        secretId: '   ',
        secretKey: 'test-secret-key',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('surrounding spaces are trimmed before the key is used', () async {
    final trimmed = CosCloudStorage.test(
      storageId: 'public',
      public: true,
      bucket: 'example-bucket',
      region: 'ap-guangzhou',
      secretId: '  test-id  ',
      secretKey: '  test-key  ',
    );
    Uri? seen;
    final mock = MockClient((request) async {
      seen = request.url;
      return http.Response('', 404);
    });

    await http.runWithClient(() async {
      await trimmed.fileExists(session: _SessionFake(), path: 'a.txt');
    }, () => mock);

    expect(seen?.queryParameters['q-ak'], 'test-id');
  });

  test(
    'unverified object is empty until verifyDirectFileUpload succeeds',
    () async {
      final bucket = _Bucket();
      final payload = Uint8List.fromList([7, 8, 9]);
      await http.runWithClient(() async {
        await storage.storeFile(
          session: _SessionFake(),
          path: 'folder/file.txt',
          byteData: ByteData.sublistView(payload),
          verified: false,
        );
        expect(
          await storage.retrieveFile(
            session: _SessionFake(),
            path: 'folder/file.txt',
          ),
          isNull,
        );
        expect(
          await storage.getPublicUrl(
            session: _SessionFake(),
            path: 'folder/file.txt',
          ),
          isNull,
        );

        expect(
          await storage.verifyDirectFileUpload(
            session: _SessionFake(),
            path: 'folder/file.txt',
          ),
          isTrue,
        );
        final got = await storage.retrieveFile(
          session: _SessionFake(),
          path: 'folder/file.txt',
        );
        expect(got, isNotNull);
        expect(Uint8List.sublistView(got!), payload);
        expect(
          await storage.getPublicUrl(
            session: _SessionFake(),
            path: 'folder/file.txt',
          ),
          isNotNull,
        );
      }, () => MockClient((request) async => bucket.serve(request)));
    },
  );

  test(
    'preventOverwrite completion fails and the original bytes stay readable',
    () async {
      final bucket = _Bucket();
      final original = Uint8List.fromList([1, 1, 1]);
      final replacement = Uint8List.fromList([2, 2, 2]);
      await http.runWithClient(() async {
        await storage.storeFile(
          session: _SessionFake(),
          path: 'folder/file.txt',
          byteData: ByteData.sublistView(original),
        );
        final accepted = await storage.acceptDirectFile(
          session: _SessionFake(),
          path: 'folder/file.txt',
          byteData: ByteData.sublistView(replacement),
          preventOverwrite: true,
        );
        expect(accepted, isFalse);
        final got = await storage.retrieveFile(
          session: _SessionFake(),
          path: 'folder/file.txt',
        );
        expect(got, isNotNull);
        expect(Uint8List.sublistView(got!), original);
      }, () => MockClient((request) async => bucket.serve(request)));
    },
  );

  test('new direct upload stays unreadable until it is verified', () async {
    final bucket = _Bucket();
    final payload = Uint8List.fromList([4, 5, 6]);
    await http.runWithClient(() async {
      final accepted = await storage.acceptDirectFile(
        session: _SessionFake(),
        path: 'folder/new.txt',
        byteData: ByteData.sublistView(payload),
        preventOverwrite: true,
      );
      expect(accepted, isTrue);
      expect(
        await storage.retrieveFile(
          session: _SessionFake(),
          path: 'folder/new.txt',
        ),
        isNull,
      );
      expect(
        await storage.getPublicUrl(
          session: _SessionFake(),
          path: 'folder/new.txt',
        ),
        isNull,
      );
      expect(
        await storage.verifyDirectFileUpload(
          session: _SessionFake(),
          path: 'folder/new.txt',
        ),
        isTrue,
      );
      final got = await storage.retrieveFile(
        session: _SessionFake(),
        path: 'folder/new.txt',
      );
      expect(Uint8List.sublistView(got!), payload);
    }, () => MockClient((request) async => bucket.serve(request)));
  });

  test('bad key or expiry does not allow deleting the upload entry', () {
    expect(
      mayDeleteDirectUploadEntry(
        found: true,
        keyMatches: false,
        expired: false,
      ),
      isFalse,
    );
    expect(
      mayDeleteDirectUploadEntry(found: true, keyMatches: true, expired: true),
      isFalse,
    );
    expect(
      mayDeleteDirectUploadEntry(
        found: false,
        keyMatches: true,
        expired: false,
      ),
      isFalse,
    );
    expect(
      mayDeleteDirectUploadEntry(found: true, keyMatches: true, expired: false),
      isTrue,
    );
  });

  test('overwrite flag round-trips through the upload key', () {
    final blocked = buildDirectUploadAuthKey(
      preventOverwrite: true,
      randomKey: 'abc',
    );
    final allowed = buildDirectUploadAuthKey(
      preventOverwrite: false,
      randomKey: 'abc',
    );
    expect(directUploadPreventsOverwrite(blocked), isTrue);
    expect(directUploadPreventsOverwrite(allowed), isFalse);
  });

  test('only an ow1- upload key prevents overwrite', () {
    expect(directUploadPreventsOverwrite('ow1-abc'), isTrue);
    expect(directUploadPreventsOverwrite('Ab12Cd34Ef56Gh78'), isFalse);
    expect(directUploadPreventsOverwrite('ow1'), isFalse);
    expect(directUploadPreventsOverwrite('ow0-abc'), isFalse);
    expect(
      directUploadPreventsOverwrite(
        buildDirectUploadAuthKey(preventOverwrite: true, randomKey: 'abc'),
      ),
      isTrue,
    );
    expect(
      directUploadPreventsOverwrite(
        buildDirectUploadAuthKey(preventOverwrite: false, randomKey: 'abc'),
      ),
      isFalse,
    );
  });

  test('unprefixed key still writes when the object already exists', () async {
    await _finishOverExisting(
      storage: storage,
      authKey: 'Ab12Cd34Ef56Gh78',
      expectAccepted: true,
    );
  });

  test('ow1- key fails and the original bytes stay', () async {
    await _finishOverExisting(
      storage: storage,
      authKey: 'ow1-abc',
      expectAccepted: false,
    );
  });

  test('ow0- key writes when the object already exists', () async {
    await _finishOverExisting(
      storage: storage,
      authKey: 'ow0-abc',
      expectAccepted: true,
    );
  });
}

Future<void> _finishOverExisting({
  required CosCloudStorage storage,
  required String authKey,
  required bool expectAccepted,
}) async {
  final bucket = _Bucket();
  const path = 'folder/file.txt';
  final original = Uint8List.fromList([1, 1, 1]);
  final replacement = Uint8List.fromList([2, 2, 2]);
  await http.runWithClient(() async {
    await storage.storeFile(
      session: _SessionFake(),
      path: path,
      byteData: ByteData.sublistView(original),
    );
    final accepted = await storage.acceptDirectFile(
      session: _SessionFake(),
      path: path,
      byteData: ByteData.sublistView(replacement),
      preventOverwrite: directUploadPreventsOverwrite(authKey),
    );
    expect(accepted, expectAccepted);
    if (!expectAccepted) {
      final got = await storage.retrieveFile(
        session: _SessionFake(),
        path: path,
      );
      expect(got, isNotNull);
      expect(Uint8List.sublistView(got!), original);
      return;
    }
    expect(
      await storage.verifyDirectFileUpload(session: _SessionFake(), path: path),
      isTrue,
    );
    final got = await storage.retrieveFile(session: _SessionFake(), path: path);
    expect(got, isNotNull);
    expect(Uint8List.sublistView(got!), replacement);
  }, () => MockClient((request) async => bucket.serve(request)));
}

class _Object {
  _Object(this.bytes, this.verified);

  Uint8List bytes;
  String? verified;
}

class _Bucket {
  final objects = <String, _Object>{};

  http.Response serve(http.Request request) {
    final key = request.url.path.replaceFirst(RegExp(r'^/'), '');
    if (request.method == 'PUT') {
      objects[key] = _Object(
        Uint8List.fromList(request.bodyBytes),
        request.headers['x-cos-meta-verified'],
      );
      return http.Response('', 204);
    }
    final object = objects[key];
    if (object == null) return http.Response('', 404);
    final headers = <String, String>{
      if (object.verified != null) 'x-cos-meta-verified': object.verified!,
    };
    if (request.method == 'HEAD') {
      return http.Response('', 200, headers: headers);
    }
    if (request.method == 'GET') {
      return http.Response.bytes(object.bytes, 200, headers: headers);
    }
    return http.Response('', 405);
  }
}
