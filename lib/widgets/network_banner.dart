import 'package:flutter/material.dart';
import '../services/connection_service.dart';

class NetworkDialog extends StatefulWidget {
  const NetworkDialog({Key? key}) : super(key: key);

  @override
  State<NetworkDialog> createState() => _NetworkDialogState();
}

class _NetworkDialogState extends State<NetworkDialog> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();

    ConnectionService.onConnectionChange.listen((hasInternet) {
      if (!hasInternet) {
        _showDialog();
      } else {
        _hideDialog();
      }
    });
  }

  void _showDialog() {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.wifi_off, color: Colors.red, size: 50),
              SizedBox(height: 16),
              Text(
                'لا يوجد اتصال بالإنترنت',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _hideDialog() {
    if (!_dialogShown) return;
    _dialogShown = true;

    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
