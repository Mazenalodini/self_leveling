import '../domain/entities/messaging_models.dart';

abstract class CloudMessageEnhancer {
  const CloudMessageEnhancer();

  Future<CloudMessageEnhancement?> enhance(CloudMessageRequest request);
}

class NoOpCloudMessageEnhancer extends CloudMessageEnhancer {
  const NoOpCloudMessageEnhancer();

  @override
  Future<CloudMessageEnhancement?> enhance(CloudMessageRequest request) async {
    return null;
  }
}
