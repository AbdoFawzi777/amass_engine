# Amass Engine (`amass_engine`)

> In-Depth Attack Surface Mapping Engine  
> **Author & Original Architect:** [Abdallah Fawzi Ali Mahmoud](https://github.com/AbdoFawzi777)  
> **Part of the RedOps Hub Monorepo Suite**

---

## 📌 Overview
`amass_engine` is a production-grade, standalone Flutter package engineered for high-performance mobile security auditing. Built with pure Dart and native Flutter MethodChannels/Isolates, it delivers enterprise-level capability directly on Android & iOS devices without relying on external Linux command-line dependencies.

---

## 🚀 New Capabilities & Features (v2.0)
- **Attack Surface Discovery:** Deep OSINT mapping of organization domain infrastructure and child entities.
- **ASN & IP Block Mapping:** Resolves Autonomous System Numbers (ASNs) and associated IP CIDR ranges.
- **Graph-Based Infrastructure Tracking:** Tracks relationships between domains, IPs, name servers, and mail exchanges.
- **Threat Intel Integration:** Integrates with open-source threat feeds for comprehensive intelligence gathering.

---

## 🛠 Usage & Integration

Add `amass_engine` to your Flutter `pubspec.yaml`:

```yaml
dependencies:
  amass_engine:
    path: ../packages/amass_engine
```

### Basic Example

```dart
import 'package:amass_engine/amass_engine.dart';

void main() async {
  final engine = AmassEngine();
  
  print('Starting Amass Engine audit...');
  final results = await engine.execute(
    target: '192.168.1.1',
  );
  
  print('Audit Complete!');
}
```

---

## 🔒 Security & Privacy
- **Zero Telemetry:** No analytics, tracking, or network calls home.
- **Encrypted Local Storage:** Integrates seamlessly with RedOps Hub AES-256 local database.
- **Thread Safety:** All heavy operations execute inside Dart Isolates to maintain 60fps UI rendering.

---

## 👤 Author & Copyright

**Abdallah Fawzi Ali Mahmoud**  
Lead Developer & Security Architect of RedOps Hub  
- **GitHub:** [@AbdoFawzi777](https://github.com/AbdoFawzi777)  
- **Telegram:** [@ABdo_FawZi1](https://telegram.me/ABdo_FawZi1)  
- **Website:** [RedOps Hub Platform](https://redops-hub.web.app)

*Copyright (c) 2026 Abdallah Fawzi Ali Mahmoud. All rights reserved.*
