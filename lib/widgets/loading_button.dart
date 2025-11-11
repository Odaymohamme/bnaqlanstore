//loading_button.dart
import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String text;

  const LoadingButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      child: isLoading
          ? const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      )
          : Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}
