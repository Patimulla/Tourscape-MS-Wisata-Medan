import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/wilayah_model.dart';

class WilayahFilterCard extends StatelessWidget {
  final List<WilayahOption> topLevelOptions;
  final List<WilayahOption> kecamatanOptions;
  final List<WilayahOption> leafOptions;
  final int? selectedTopLevelId;
  final int? selectedKecamatanId;
  final int? selectedLeafId;
  final bool showAllKecamatan;
  final bool showAllLeafWilayah;
  final bool showSelectedRoads;
  final bool isLoading;
  final VoidCallback onResetFilters;
  final ValueChanged<int?> onTopLevelChanged;
  final ValueChanged<int?> onKecamatanChanged;
  final ValueChanged<int?> onLeafChanged;
  final ValueChanged<bool> onShowAllKecamatanChanged;
  final ValueChanged<bool> onShowAllLeafWilayahChanged;
  final ValueChanged<bool> onShowSelectedRoadsChanged;

  const WilayahFilterCard({
    super.key,
    required this.topLevelOptions,
    required this.kecamatanOptions,
    required this.leafOptions,
    required this.selectedTopLevelId,
    required this.selectedKecamatanId,
    required this.selectedLeafId,
    required this.showAllKecamatan,
    required this.showAllLeafWilayah,
    required this.showSelectedRoads,
    required this.isLoading,
    required this.onResetFilters,
    required this.onTopLevelChanged,
    required this.onKecamatanChanged,
    required this.onLeafChanged,
    required this.onShowAllKecamatanChanged,
    required this.onShowAllLeafWilayahChanged,
    required this.onShowSelectedRoadsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_tree_rounded,
                    size: 18,
                    color: AppTheme.textPrimary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter Wilayah',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
              const SizedBox(height: 6),
              Text(
                'Pilih area utama, lalu lanjutkan ke kecamatan dan kelurahan/desa.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildDropdown<int?>(
                label: '1. Kota / Kabupaten',
                value: selectedTopLevelId,
                hint: 'Pilih area utama terlebih dahulu',
                items: topLevelOptions
                    .map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text('${item.nama} (${item.tipeLabel})'),
                      ),
                    )
                    .toList(),
                onChanged: onTopLevelChanged,
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                label: 'Tampilkan seluruh kecamatan dari kota/kabupaten terpilih',
                value: showAllKecamatan,
                enabled: selectedTopLevelId != null,
                onChanged: onShowAllKecamatanChanged,
              ),
              const SizedBox(height: 8),
              _buildDropdown<int?>(
                label: '2. Kecamatan',
                value: selectedKecamatanId,
                hint: kecamatanOptions.isEmpty
                    ? 'Pilih wilayah induk dulu'
                    : 'Pilih kecamatan',
                items: kecamatanOptions
                    .map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.nama),
                      ),
                    )
                    .toList(),
                onChanged: kecamatanOptions.isEmpty ? null : onKecamatanChanged,
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                label: 'Tampilkan seluruh kelurahan/desa dari kecamatan terpilih',
                value: showAllLeafWilayah,
                enabled: selectedKecamatanId != null,
                onChanged: onShowAllLeafWilayahChanged,
              ),
              const SizedBox(height: 8),
              _buildDropdown<int?>(
                label: '3. Kelurahan / Desa',
                value: selectedLeafId,
                hint: leafOptions.isEmpty
                    ? 'Pilih kecamatan dulu'
                    : 'Pilih kelurahan atau desa',
                items: leafOptions
                    .map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text('${item.nama} (${item.tipeLabel})'),
                      ),
                    )
                    .toList(),
                onChanged: leafOptions.isEmpty ? null : onLeafChanged,
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                label: 'Tampilkan seluruh jalan di kelurahan/desa terpilih',
                value: showSelectedRoads,
                enabled: selectedLeafId != null,
                onChanged: onShowSelectedRoadsChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          hint: Text(hint),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text('Tidak dipilih'),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
