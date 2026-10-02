import 'package:serverpod/serverpod.dart';
import 'package:tencent_cos_cloud_storage_serverpod/tencent_cos_cloud_storage_serverpod.dart'
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
