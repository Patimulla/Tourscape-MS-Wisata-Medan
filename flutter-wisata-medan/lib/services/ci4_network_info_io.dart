import 'dart:io';

Future<List<({String prefix, int lastOctet})>> getPrivateSubnetInfos() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );

  final infos = <({String prefix, int lastOctet})>[];
  final seen = <String>{};

  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final ip = address.address;
      if (!_isPrivateIpv4(ip)) {
        continue;
      }

      final segments = ip.split('.');
      if (segments.length != 4) {
        continue;
      }

      final prefix = '${segments[0]}.${segments[1]}.${segments[2]}';
      final lastOctet = int.tryParse(segments[3]);
      if (lastOctet == null) {
        continue;
      }

      final key = '$prefix:$lastOctet';
      if (seen.add(key)) {
        infos.add((prefix: prefix, lastOctet: lastOctet));
      }
    }
  }

  return infos;
}

bool _isPrivateIpv4(String ip) {
  final segments = ip.split('.');
  if (segments.length != 4) {
    return false;
  }

  final first = int.tryParse(segments[0]);
  final second = int.tryParse(segments[1]);

  if (first == null || second == null) {
    return false;
  }

  if (first == 10) {
    return true;
  }

  if (first == 192 && second == 168) {
    return true;
  }

  return first == 172 && second >= 16 && second <= 31;
}
