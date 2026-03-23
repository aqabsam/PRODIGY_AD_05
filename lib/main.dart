import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlk;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

void main() {
  runApp(const QrIntelApp());
}

class QrIntelApp extends StatelessWidget {
  const QrIntelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B5FFF),
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'QR Intel',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const QrHomePage(),
    );
  }
}

class QrHomePage extends StatefulWidget {
  const QrHomePage({super.key});

  @override
  State<QrHomePage> createState() => _QrHomePageState();
}

class _QrHomePageState extends State<QrHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  QrPayload? _payload;
  bool _isProcessing = false;

  Future<void> _scanWithCamera() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted) return;
    if (result == null || result.trim().isEmpty) return;
    setState(() => _payload = QrPayload.fromRaw(result));
  }

  Future<void> _scanFromImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isProcessing = true);
    final scanner = mlk.BarcodeScanner(formats: [mlk.BarcodeFormat.qrCode]);
    try {
      final inputImage = mlk.InputImage.fromFilePath(image.path);
      final barcodes = await scanner.processImage(inputImage);
      mlk.Barcode? qr;
      for (final code in barcodes) {
        if (code.rawValue != null && code.rawValue!.trim().isNotEmpty) {
          qr = code;
          break;
        }
      }
      if (!mounted) return;
      final raw = qr?.rawValue;
      if (raw == null || raw.trim().isEmpty) {
        _showSnack('No QR code found in that image.');
      } else {
        setState(() => _payload = QrPayload.fromRaw(raw));
      }
    } catch (_) {
      if (mounted) _showSnack('Could not read that QR image. Try a clearer shot.');
    } finally {
      await scanner.close();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _copyToClipboard() {
    final raw = _payload?.rawValue;
    if (raw == null) return;
    Clipboard.setData(ClipboardData(text: raw));
    _showSnack('Copied to clipboard.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final payload = _payload;

    return Scaffold(
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final horizontalPadding = isWide ? 32.0 : 20.0;
                final content = _HomeContent(
                  payload: payload,
                  isProcessing: _isProcessing,
                  onScan: _scanWithCamera,
                  onUpload: _scanFromImage,
                  onCopy: _copyToClipboard,
                  isWide: isWide,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.payload,
    required this.isProcessing,
    required this.onScan,
    required this.onUpload,
    required this.onCopy,
    required this.isWide,
  });

  final QrPayload? payload;
  final bool isProcessing;
  final VoidCallback onScan;
  final VoidCallback onUpload;
  final VoidCallback onCopy;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final header = Row(
      children: [
        _GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 14,
          child: Icon(Icons.qr_code_2, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Intel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Scan or upload to reveal every detail.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.62),
                  ),
            ),
          ],
        ),
      ],
    );

    final actions = _ActionCard(
      title: 'Decode any QR',
      subtitle: 'Camera scan or upload an image from your gallery.',
      primaryLabel: 'Scan with Camera',
      secondaryLabel: 'Upload QR Image',
      onPrimary: onScan,
      onSecondary: onUpload,
      isBusy: isProcessing,
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _DetailsCard(
          payload: payload,
          onCopy: onCopy,
        ),
      ],
    );

    final insights = _InsightRow(payload: payload);

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 20),
          actions,
          const SizedBox(height: 20),
          details,
          const SizedBox(height: 20),
          insights,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  actions,
                  const SizedBox(height: 20),
                  insights,
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: details),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.isBusy,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      overlayGradient: LinearGradient(
        colors: [
          scheme.primary.withOpacity(0.18),
          scheme.secondaryContainer.withOpacity(0.38),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : onPrimary,
                  icon: const Icon(Icons.center_focus_strong),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onSecondary,
                  icon: isBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(secondaryLabel),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: scheme.primary.withOpacity(0.45)),
                    foregroundColor: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.payload, required this.onCopy});

  final QrPayload? payload;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final payload = this.payload;

    if (payload == null) {
      return _GlassCard(
        width: double.infinity,
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No QR decoded yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a code to reveal the message type, structured fields, and raw content.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return _GlassCard(
      width: double.infinity,
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(payload.icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payload.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...payload.fields.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              payload.rawValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.8),
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy raw'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.payload});

  final QrPayload? payload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = payload?.insights ??
        const [
          'Highlights appear after your first scan.',
          'Scan in bright light for best accuracy.',
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 520;
        final children = [
          for (int i = 0; i < info.length; i++)
            Expanded(
              child: _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                margin: EdgeInsets.only(right: i == info.length - 1 ? 0 : 12),
                child: Text(
                  info[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
        ];

        if (!isTight) {
          return Row(children: children);
        }

        return Column(
          children: [
            for (int i = 0; i < info.length; i++)
              _GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 16,
                margin: EdgeInsets.only(bottom: i == info.length - 1 ? 0 : 12),
                child: Text(
                  info[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withOpacity(0.12),
                scheme.surface,
                scheme.secondary.withOpacity(0.14),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _GlowBlob(
            color: scheme.primary.withOpacity(0.22),
            size: 200,
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _GlowBlob(
            color: scheme.secondary.withOpacity(0.2),
            size: 180,
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final ms.MobileScannerController _controller = ms.MobileScannerController(
    detectionSpeed: ms.DetectionSpeed.noDuplicates,
  );
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(ms.BarcodeCapture capture) {
    if (_hasResult) return;
    ms.Barcode? barcode;
    for (final code in capture.barcodes) {
      if (code.rawValue != null && code.rawValue!.trim().isNotEmpty) {
        barcode = code;
        break;
      }
    }
    final value = barcode?.rawValue;
    if (value == null) return;

    _hasResult = true;
    _controller.stop();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Scan QR'),
        actions: [
          ValueListenableBuilder<ms.MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final icon = state.torchState == ms.TorchState.on
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded;
              return IconButton(
                onPressed: _controller.toggleTorch,
                icon: Icon(icon),
              );
            },
          ),
          IconButton(
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ms.MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _GlassCard(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Text(
                'Align the code inside the frame to auto-detect.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Center(
            child: _ScanFrame(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _FramePainter(color: color),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const corner = 28.0;
    final rect = Offset.zero & size;

    for (final angle in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(angle);
      canvas.translate(-rect.center.dx, -rect.center.dy);

      canvas.drawLine(
        Offset(rect.left, rect.top + corner),
        Offset(rect.left, rect.top),
        paint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left + corner, rect.top),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.borderRadius = 20,
    this.overlayGradient,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double borderRadius;
  final Gradient? overlayGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              gradient: overlayGradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class QrPayload {
  QrPayload({
    required this.rawValue,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.icon,
    required this.insights,
  });

  final String rawValue;
  final String title;
  final String subtitle;
  final Map<String, String> fields;
  final IconData icon;
  final List<String> insights;

  factory QrPayload.fromRaw(String raw) {
    final trimmed = raw.trim();
    final upper = trimmed.toUpperCase();

    if (upper.startsWith('WIFI:')) {
      final map = _parseKeyValues(trimmed.substring(5));
      return QrPayload(
        rawValue: trimmed,
        title: 'Wi-Fi Network',
        subtitle: map['S'] ?? 'Hidden network',
        fields: {
          'SSID': map['S'] ?? 'Unknown',
          'Security': map['T'] ?? 'Open',
          'Password': map['P']?.isEmpty == true ? 'None' : (map['P'] ?? 'Unknown'),
          'Hidden': map['H'] == 'true' ? 'Yes' : 'No',
        },
        icon: Icons.wifi_rounded,
        insights: const [
          'Connect instantly from supported devices.',
          'Never share passwords manually again.',
        ],
      );
    }

    if (upper.startsWith('BEGIN:VCARD')) {
      return QrPayload(
        rawValue: trimmed,
        title: 'Contact Card',
        subtitle: 'vCard profile',
        fields: {
          'Type': 'vCard',
          'Length': '${trimmed.length} chars',
        },
        icon: Icons.contact_phone_rounded,
        insights: const [
          'Add to contacts in one tap.',
          'Ideal for business cards.',
        ],
      );
    }

    if (upper.startsWith('MECARD:')) {
      return QrPayload(
        rawValue: trimmed,
        title: 'Contact Card',
        subtitle: 'MeCard profile',
        fields: {
          'Type': 'MeCard',
          'Length': '${trimmed.length} chars',
        },
        icon: Icons.contact_page_rounded,
        insights: const [
          'MeCard format recognized by many apps.',
          'Great for quick contact sharing.',
        ],
      );
    }

    if (upper.startsWith('GEO:')) {
      final coords = trimmed.substring(4).split(',');
      return QrPayload(
        rawValue: trimmed,
        title: 'Location',
        subtitle: 'Geolocation coordinates',
        fields: {
          'Latitude': coords.isNotEmpty ? coords[0] : 'Unknown',
          'Longitude': coords.length > 1 ? coords[1] : 'Unknown',
        },
        icon: Icons.location_on_rounded,
        insights: const [
          'Perfect for events and meetups.',
          'Share places instantly.',
        ],
      );
    }

    if (upper.startsWith('SMSTO:') || upper.startsWith('SMS:')) {
      final content = trimmed.split(':');
      final number = content.length > 1 ? content[1] : 'Unknown';
      final body = content.length > 2 ? content.sublist(2).join(':') : '';
      return QrPayload(
        rawValue: trimmed,
        title: 'SMS Message',
        subtitle: number,
        fields: {
          'Number': number,
          'Message': body.isEmpty ? 'Empty' : body,
        },
        icon: Icons.sms_rounded,
        insights: const [
          'Quickly draft a text message.',
          'Great for support hotlines.',
        ],
      );
    }

    if (upper.startsWith('TEL:')) {
      final number = trimmed.substring(4);
      return QrPayload(
        rawValue: trimmed,
        title: 'Phone Number',
        subtitle: number,
        fields: {
          'Number': number,
          'Type': 'Telephone',
        },
        icon: Icons.call_rounded,
        insights: const [
          'Tap to dial on most devices.',
          'Useful for quick callbacks.',
        ],
      );
    }

    if (upper.startsWith('MAILTO:') || upper.startsWith('MATMSG:')) {
      final email = upper.startsWith('MAILTO:')
          ? trimmed.substring(7)
          : _parseKeyValues(trimmed.substring(7))['TO'] ?? 'Unknown';
      return QrPayload(
        rawValue: trimmed,
        title: 'Email Draft',
        subtitle: email,
        fields: {
          'To': email,
          'Type': 'Email',
        },
        icon: Icons.email_rounded,
        insights: const [
          'Pre-fills an email message.',
          'Great for support desks.',
        ],
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return QrPayload(
        rawValue: trimmed,
        title: 'Website Link',
        subtitle: uri.host,
        fields: {
          'Scheme': uri.scheme.toUpperCase(),
          'Host': uri.host,
          'Path': uri.path.isEmpty ? '/' : uri.path,
        },
        icon: Icons.public_rounded,
        insights: const [
          'Tap to open in a browser.',
          'Great for menus and promos.',
        ],
      );
    }

    if (_looksLikeEmail(trimmed)) {
      return QrPayload(
        rawValue: trimmed,
        title: 'Email Address',
        subtitle: trimmed,
        fields: {
          'Email': trimmed,
          'Type': 'Plain email',
        },
        icon: Icons.mark_email_read_rounded,
        insights: const [
          'Send mail in one tap.',
          'Great for resumes and portfolios.',
        ],
      );
    }

    if (_looksLikePhone(trimmed)) {
      return QrPayload(
        rawValue: trimmed,
        title: 'Phone Number',
        subtitle: trimmed,
        fields: {
          'Number': trimmed,
          'Type': 'Plain phone',
        },
        icon: Icons.phone_in_talk_rounded,
        insights: const [
          'Quick contact sharing.',
          'Great for storefronts.',
        ],
      );
    }

    return QrPayload(
      rawValue: trimmed,
      title: 'Text Payload',
      subtitle: 'Custom message',
      fields: {
        'Length': '${trimmed.length} chars',
        'Encoding': 'UTF-8',
      },
      icon: Icons.text_snippet_rounded,
      insights: const [
        'Share any message instantly.',
        'Works offline too.',
      ],
    );
  }

  static Map<String, String> _parseKeyValues(String value) {
    final fields = <String, String>{};
    for (final part in value.split(';')) {
      if (!part.contains(':')) continue;
      final pieces = part.split(':');
      final key = pieces.first.toUpperCase();
      final val = pieces.sublist(1).join(':');
      fields[key] = val;
    }
    return fields;
  }

  static bool _looksLikeEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  static bool _looksLikePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length >= 7 && digits.length <= 15;
  }
}
