import 'package:material_ui/material_ui.dart';

class CompanyDetails {
  final String name;
  final IconData icon;
  final Color color;
  final String Function(List<int> data)? subTypeParser;

  const CompanyDetails({
    required this.name,
    required this.icon,
    this.color = Colors.blue,
    this.subTypeParser,
  });
}

class CompanyIdentifiers {
  // A compilation of Bluetooth SIG Company Identifiers, feel free to add more (though you probably wont need to since we're only using it for apple devices.)
  static const Map<int, CompanyDetails> registry = {
    76: CompanyDetails(
      name: 'Apple Inc.',
      icon: Icons.apple,
      color: Colors.grey,
      subTypeParser: _parseAppleData

    )};
  // Company specific parsing routines, you could add one yourself if you're using this app for something else.
  // Apple-specific sub-type parsing sub-routine
  static String _parseAppleData(List<int> data) {
    if (data.isEmpty) return 'Apple Device';
    final typeByte = data[0];
    switch (typeByte) {
      case 0x02: return 'Apple iBeacon';
      case 0x05: return 'Apple AirDrop';
      case 0x07: return 'Apple AirPods/Audio';
      case 0x10: return 'Apple Continuity/Handoff';
      default: return 'Apple Device';
    }
  }
}
