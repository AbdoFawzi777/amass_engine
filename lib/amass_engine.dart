import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'identity_shield.dart';

/// 🕵️ Amass Absolute Engine v20.0 - Full Attack Surface & Cloud Topology Profiler
class AmassEngine {
  static final AmassEngine _instance = AmassEngine._internal();
  factory AmassEngine() => _instance;
  AmassEngine._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    _initialized = true;
  }

  /// Deep Infrastructure Mapping: Subdomains + DNS + Live IP Probing + Cloud Provider
  Future<AmassResult> enumerate(
    String rawDomain, {
    bool resolveLiveIps = true,
    Function(int progress, String status)? onProgress,
  }) async {
    if (!IdentityShield.check()) throw Exception("Security Violation: Core Integrity Check Failed");

    final cleanDomain = rawDomain.trim().replaceAll(RegExp(r'https?://'), '').split('/')[0].toLowerCase();
    final Set<String> subs = {};
    final Set<String> ips = {};
    final Set<String> sources = {};
    final startTime = DateTime.now();

    onProgress?.call(15, "Synthesizing multi-feed OSINT indicators for $cleanDomain...");

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

    final validSubs = subs.where((s) => s.isNotEmpty && (s == cleanDomain || s.endsWith('.$cleanDomain'))).toList()..sort();

    onProgress?.call(60, "Resolving active IPv4/IPv6 endpoints and routing topology...");

    if (resolveLiveIps && validSubs.isNotEmpty) {
      final topSubs = validSubs.take(15).toList();
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

    onProgress?.call(90, "Identifying Autonomous System Numbers (ASN) & Cloud Hosting...");
    final cloudProvider = _inferCloudProvider(ips.toList());

    onProgress?.call(100, "Amass topology mapping complete.");

    return AmassResult(
      domain: cleanDomain,
      subdomains: validSubs,
      ips: ips.toList()..sort(),
      sources: sources.toList()..sort(),
      cloudProvider: cloudProvider,
      duration: DateTime.now().difference(startTime),
    );
  }

  String _inferCloudProvider(List<String> ipList) {
    for (final ip in ipList) {
      if (ip.startsWith('104.') || ip.startsWith('172.6') || ip.startsWith('188.114')) return 'Cloudflare Enterprise CDN';
      if (ip.startsWith('185.199.') || ip.startsWith('140.82.')) return 'GitHub Inc. / Fastly';
      if (ip.startsWith('52.') || ip.startsWith('54.') || ip.startsWith('3.') || ip.startsWith('18.')) return 'Amazon Web Services (AWS)';
      if (ip.startsWith('34.') || ip.startsWith('35.') || ip.startsWith('104.196')) return 'Google Cloud Platform (GCP)';
      if (ip.startsWith('20.') || ip.startsWith('40.') || ip.startsWith('51.')) return 'Microsoft Azure';
      if (ip.startsWith('157.245.') || ip.startsWith('174.138.') || ip.startsWith('159.203.')) return 'DigitalOcean LLC';
    }
    return 'Tier-1 ISP / Dedicated Hosting';
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
  final String cloudProvider;
  final Duration? duration;

  AmassResult({
    required this.domain,
    required this.subdomains,
    required this.ips,
    required this.sources,
    this.cloudProvider = 'Unknown Infrastructure',
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'subdomains_count': subdomains.length,
    'subdomains': subdomains,
    'ips_count': ips.length,
    'ips': ips,
    'sources': sources,
    'cloud_provider': cloudProvider,
    'duration_ms': duration?.inMilliseconds ?? 0,
  };
}
