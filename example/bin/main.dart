import 'package:serverpod/serverpod.dart';
import 'package:serverpod_cloud_storage_cos/serverpod_cloud_storage_cos.dart'
    as cos;

void configureCosStorage(Serverpod pod) {
  pod.addCloudStorage(
    cos.CosCloudStorage(
      serverpod: pod,
      storageId: 'public',
      public: true,
      region: 'ap-guangzhou',
      bucket: 'your-bucket-name',
    ),
  );

  cos.registerCosCloudStorageEndpoint(pod);
}

void main() {
  // This file is a usage example for server-side configuration.
}
