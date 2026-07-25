/// 🕵️ Amass Engine - Advanced subdomain enumeration for Flutter
library amass_engine;

import 'dart:convert';
import 'package:http/http.dart' as http;

class AmassEngine {
  static final AmassEngine _instance = AmassEngine._internal();
  factory AmassEngine() => _instance;
  AmassEngine._internal();

  bool _initialized = false;

  /// 🚀 تهيئة المحرك
  Future<void> initialize() async {
    _initialized = true;
  }

  /// 🔍 تعداد متقدم
  Future<AmassResult> enumerate(String domain) async {
    final subdomains = <String>{};
    final sources = <String>[];
    final ips = <String>[];

    // 1. AlienVault OTX
    try {
      final response = await http.get(
        Uri.parse('https://otx.alienvault.com/api/v1/indicators/domain/$domain/passive_dns'),
      );
      if (response.statusCode == 200) {
        sources.add('AlienVault OTX');
        final data = jsonDecode(response.body);
        for (final record in data['passive_dns']) {
          final host = record['hostname'] as String?;
          if (host != null && host.contains(domain)) {
            subdomains.add(host);
            if (record.containsKey('address')) {
              ips.add(record['address']);
            }
          }
        }
      }
    } catch (_) {}

    // 2. SecurityTrails
    try {
      final response = await http.get(
        Uri.parse('https://api.securitytrails.com/v1/domain/$domain/subdomains'),
        headers: {'APIKEY': 'demo'},
      );
      if (response.statusCode == 200) {
        sources.add('SecurityTrails');
        final data = jsonDecode(response.body);
        if (data.containsKey('subdomains')) {
          for (final sub in data['subdomains']) {
            subdomains.add('$sub.$domain');
          }
        }
      }
    } catch (_) {}

    // 3. OpenData (OWASP)
    try {
      final response = await http.get(
        Uri.parse('https://open-data.owasp.org/amass/subdomains/$domain'),
      );
      if (response.statusCode == 200) {
        sources.add('OWASP OpenData');
        final data = jsonDecode(response.body);
        if (data is List) {
          for (final item in data) {
            if (item is String && item.contains(domain)) {
              subdomains.add(item);
            }
          }
        }
      }
    } catch (_) {}

    return AmassResult(
      domain: domain,
      subdomains: subdomains.toList(),
      sources: sources,
      ips: ips,
    );
  }

  bool get isInitialized => _initialized;
}

class AmassResult {
  final String domain;
  final List<String> subdomains;
  final List<String> sources;
  final List<String> ips;
  
  AmassResult({
    required this.domain,
    required this.subdomains,
    required this.sources,
    required this.ips,
  });
}
