import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/scan_result.dart';

/// Tile widget for displaying a scan result in a list
class ScanTile extends StatelessWidget {
  final ScanResult scan;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showThumbnail;

  const ScanTile({
    super.key,
    required this.scan,
    this.onTap,
    this.onDelete,
    this.showThumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final urgencyColor = AppColors.urgencyColor(scan.severity);
    final confidenceColor = AppColors.confidenceColor(scan.confidence);
    final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(scan.timestamp);
    final percentage = (scan.confidence * 100).toStringAsFixed(1);

    return Dismissible(
      key: Key(scan.id),
      direction:
          onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Scan'),
            content:
                const Text('Are you sure you want to delete this scan record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail
                if (showThumbnail)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _buildThumbnail(),
                  ),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              scan.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: urgencyColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                scan.disease,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: urgencyColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 12, color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.speed_rounded,
                              size: 14, color: confidenceColor),
                          const SizedBox(width: 4),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: confidenceColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (scan.imagePath != null && scan.imagePath!.isNotEmpty) {
      final file = File(scan.imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    if (scan.imageUrl != null && scan.imageUrl!.startsWith('data:image')) {
      try {
        final base64Content = scan.imageUrl!.split(',').last;
        final bytes = base64Decode(base64Content);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        debugPrint('[ScanTile] Error decoding base64 image: $e');
      }
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.background,
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textTertiary,
        size: 24,
      ),
    );
  }
}
