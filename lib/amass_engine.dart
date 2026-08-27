import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'identity_shield.dart';

/// 🕵️ Amass Engine v9.0 - Attack Surface & Network Topology Profiler
class AmassEngine {
  static final AmassEngine _instance = AmassEngine._internal();
  factory AmassEngine() => _instance;
  AmassEngine._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    _initialized = true;
  }

  /// 🚀 Deep Infrastructure Mapping: Subdomains + Passive DNS + Resolved IPs
  Future<AmassResult> enumerate(String rawDomain, {bool resolveLiveIps = true}) async {
    if (!IdentityShield.check()) throw Exception("Security Violation: Core Integrity Check Failed");

    final cleanDomain = rawDomain.trim().replaceAll(RegExp(r'https?://'), '').split('/')[0].toLowerCase();
    final Set<String> subs = {};
    final Set<String> ips = {};
    final Set<String> sources = {};
    final startTime = DateTime.now();

    final jobs = [
      _fetchAlienVault(cleanDomain),
      _fetchCrtSh(cleanDomain),
      _fetchHackerTarget(cleanDomain),
    ];

    final all = await Future.wait(jobs);
    for (final r in all) {
      if (r != null) {
        subs.addAll(r.subdomains.map((s) => s.replaceAll('*.', '').trim().toLowerCase()));
        ips.addAll(r.ips);
        sources.add(r.source);
      }
    }

    // Clean valid subdomains
    final validSubs = subs.where((s) => s.isNotEmpty && (s == cleanDomain || s.endsWith('.$cleanDomain'))).toList()..sort();

    // Resolve IPs for top discovered subdomains
    if (resolveLiveIps && validSubs.isNotEmpty) {
      final topSubs = validSubs.take(10).toList();
      final resolveFutures = topSubs.map((s) async {
        try {
          final addresses = await InternetAddress.lookup(s).timeout(const Duration(seconds: 2));
          return addresses.map((a) => a.address).toList();
        } catch (_) {
          return <String>[];
        }
      });
      final resolved = await Future.wait(resolveFutures);
      for (final ipList in resolved) {
        ips.addAll(ipList);
      }
    }

    return AmassResult(
      domain: cleanDomain,
      subdomains: validSubs,
      ips: ips.toList()..sort(),
      sources: sources.toList()..sort(),
      duration: DateTime.now().difference(startTime),
    );
  }

  Future<SourceResult?> _fetchAlienVault(String domain) async {
    try {
      final resp = await http.get(
        Uri.parse('https://otx.alienvault.com/api/v1/indicators/domain/$domain/passive_dns'),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data['passive_dns'] as List? ?? [];
        return SourceResult(
          source: 'AlienVault OTX',
          subdomains: list.map((e) => e['hostname'].toString()).toList(),
          ips: list.where((e) => e['address'] != null).map((e) => e['address'].toString()).toList(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<SourceResult?> _fetchCrtSh(String domain) async {
    try {
      final resp = await http.get(
        Uri.parse('https://crt.sh/?q=%25.$domain&output=json'),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        final list = <String>[];
        for (final item in data) {
          final name = item['name_value'] ?? item['common_name'];
          if (name != null) {
            for (final sub in name.toString().split('\n')) {
              list.add(sub.trim());
            }
          }
        }
        return SourceResult(source: 'crt.sh Certificate Transparency', subdomains: list, ips: []);
      }
    } catch (_) {}
    return null;
  }

  Future<SourceResult?> _fetchHackerTarget(String domain) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.hackertarget.com/hostsearch/?q=$domain'),
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200 && !resp.body.contains('error')) {
        final subs = <String>[];
        final ips = <String>[];
        for (final line in resp.body.split('\n')) {
          if (line.contains(',')) {
            final parts = line.split(',');
            subs.add(parts[0].trim());
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              ips.add(parts[1].trim());
            }
          }
        }
        return SourceResult(source: 'HackerTarget DNS', subdomains: subs, ips: ips);
      }
    } catch (_) {}
    return null;
  }
}

class SourceResult {
  final String source;
  final List<String> subdomains;
  final List<String> ips;

  SourceResult({required this.source, required this.subdomains, required this.ips});
}

class AmassResult {
  final String domain;
  final List<String> subdomains;
  final List<String> ips;
  final List<String> sources;
  final Duration? duration;

  AmassResult({
    required this.domain,
    required this.subdomains,
    required this.ips,
    required this.sources,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'subdomains_count': subdomains.length,
    'subdomains': subdomains,
    'ips_count': ips.length,
    'ips': ips,
    'sources': sources,
    'duration_ms': duration?.inMilliseconds ?? 0,
  };
}
