import 'dart:io';
import 'package:flutter/material.dart';

class MediaPickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final File? previewImage;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const MediaPickerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPick,
    this.previewImage,
    this.fileName,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = previewImage != null || fileName != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.withOpacity(0.25)),
      ),
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: previewImage != null
                      ? Image.file(previewImage!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.amber.withOpacity(0.12),
                          child: Icon(icon, color: Colors.amber),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.amber)),
                    const SizedBox(height: 2),
                    Text(
                      hasContent
                          ? (fileName ?? previewImage!.path.split('/').last)
                          : subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasContent && onClear != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
