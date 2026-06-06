import 'package:flutter/material.dart';

import '../models/kecamatan_model.dart';

class KecamatanFilterCard extends StatelessWidget {
  final List<KecamatanOption> kecamatanOptions;
  final int? selectedKecamatanId;
  final bool isLoading;
  final ValueChanged<int?> onChanged;

  const KecamatanFilterCard({
    super.key,
    required this.kecamatanOptions,
    required this.selectedKecamatanId,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 270,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Filter Kecamatan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: selectedKecamatanId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Pilih kecamatan'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua Kecamatan'),
                ),
                ...kecamatanOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text('${item.namaKecamatan} (${item.wilayahLabel})'),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
