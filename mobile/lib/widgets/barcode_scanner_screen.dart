import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Push this screen and await a `String?` (barcode) result.
class BarcodeScannerScreen extends StatefulWidget {
  final String title;
  final bool continuous;
  const BarcodeScannerScreen({
    super.key,
    this.title = 'Scanner',
    this.continuous = false,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final code = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _ctrl.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _ctrl.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.keyboard),
              label: const Text('Saisie manuelle'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper: open scanner; if user cancels with manual entry button, prompt.
Future<String?> scanOrEnterBarcode(BuildContext context,
    {String title = 'Scanner un code'}) async {
  final code = await Navigator.of(context).push<String?>(
    MaterialPageRoute(builder: (_) => BarcodeScannerScreen(title: title)),
  );
  if (code != null && code.isNotEmpty) return code;

  // Manual entry fallback
  if (!context.mounted) return null;
  final ctrl = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Saisir le code-barres'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'EAN / QR / ID'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
