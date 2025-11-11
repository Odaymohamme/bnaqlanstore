//customer_item_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// موديل صغير ليمثّل بيانات الصنف المخصّص
class CustomItem {
  final String name;
  final String description;
  final String unit;
  final int quantity;
  final double price;
  final File? imageFile;

  CustomItem({
    required this.name,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.price,
    this.imageFile,
  });
}

/// حوار لإدخال بيانات الصنف المخصّص
class CustomItemDialog extends StatefulWidget {
  @override
  State<CustomItemDialog> createState() => _CustomItemDialogState();
}

class _CustomItemDialogState extends State<CustomItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '', _desc = '', _unit = 'وحدة';
  int    _qty  = 1;
  double _price = 0;
  File?  _image;
  final picker = ImagePicker();

  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      title: const Text('طلب صنف مخصص'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                onSaved: (v) => _name = v!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الوصف'),
                onSaved: (v) => _desc = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'السعر'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                double.tryParse(v!) == null ? 'عدد غير صالح' : null,
                onSaved: (v) => _price = double.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الوحدة'),
                initialValue: 'وحدة',
                onSaved: (v) => _unit = v!,
              ),
              Row(
                children: [
                  const Text('الكمية:'),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  ),
                  Text('$_qty'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _qty++),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final f = await picker.pickImage(
                      source: ImageSource.gallery);
                  if (f != null) setState(() => _image = File(f.path));
                },
                child: Container(
                  height: 80,
                  width: 80,
                  color: Colors.grey[200],
                  child: _image == null
                      ? const Icon(Icons.camera_alt)
                      : Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('إلغاء'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        ElevatedButton(
          child: const Text('إضافة'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(ctx).pop(CustomItem(
                name: _name,
                description: _desc,
                unit: _unit,
                quantity: _qty,
                price: _price,
                imageFile: _image,
              ));
            }
          },
        )
      ],
    );
  }
}
