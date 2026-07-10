import 'demo_storage_contract.dart';
import 'demo_storage_io.dart'
    if (dart.library.html) 'demo_storage_web.dart'
    as platform;

export 'demo_storage_contract.dart';

DemoStorage createDemoStorage() => platform.createPlatformDemoStorage();
