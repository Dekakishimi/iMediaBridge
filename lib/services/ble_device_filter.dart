import 'package:material_ui/material_ui.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '/models/app_manufacturer_ids.dart';

class BleDeviceInfo {
  final String detectedName;
  final IconData icon;
  final Color iconColor;
  final bool isKnownCompany;

  BleDeviceInfo({
    required this.detectedName,
    required this.icon,
    required this.iconColor,
    required this.isKnownCompany,
  });
}

class BleDeviceFilter {
  static BleDeviceInfo getDeviceInfo(ScanResult result) {
    // will prioritize the actual advertised platform name if present
    if (result.device.platformName.isNotEmpty) {
      return BleDeviceInfo(
        detectedName: result.device.platformName,
        icon: Icons.bluetooth,
        iconColor: Colors.blue,
        isKnownCompany: false,
      );
    }

    // use manufacturer ID registry
    final manufacturerData = result.advertisementData.manufacturerData;

    for (int id in manufacturerData.keys) {
      if (CompanyIdentifiers.registry.containsKey(id)) {
        final company = CompanyIdentifiers.registry[id]!;
        final rawBytes = manufacturerData[id] ?? [];

        // Use custom parser if available
        final String localizedName = company.subTypeParser != null
            ? company.subTypeParser!(rawBytes)
            : company.name;

        return BleDeviceInfo(
          detectedName: localizedName,
          icon: company.icon,
          iconColor: company.color,
          isKnownCompany: true,
        );
      }
    }

    // default
    return BleDeviceInfo(
      detectedName: 'Unknown Device',
      icon: Icons.bluetooth,
      iconColor: Colors.grey,
      isKnownCompany: false,
    );
  }
}
