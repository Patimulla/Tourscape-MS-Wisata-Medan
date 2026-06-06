import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/app_theme.dart';
import '../models/geojson_layer_model.dart';

class GeoJsonFeatureLayer extends StatelessWidget {
  final GeoLayerData? data;
  final bool visible;
  final Color lineColor;
  final double lineWidth;
  final Color polygonFillColor;
  final Color polygonBorderColor;
  final double polygonBorderWidth;

  const GeoJsonFeatureLayer({
    super.key,
    required this.data,
    required this.visible,
    this.lineColor = const Color(0xFF64748B),
    this.lineWidth = 2,
    this.polygonFillColor = const Color(0x00000000),
    this.polygonBorderColor = const Color(0xFF2563EB),
    this.polygonBorderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || data == null || data!.isEmpty) {
      return const SizedBox.shrink();
    }

    final polylineWidgets = data!.lines.isEmpty
        ? const <Widget>[]
        : [
            PolylineLayer(
              polylines: data!.lines
                  .map(
                    (line) => Polyline(
                      points: line.points,
                      strokeWidth: lineWidth,
                      color: lineColor,
                    ),
                  )
                  .toList(),
            ),
          ];

    final polygonWidgets = data!.polygons.isEmpty
        ? const <Widget>[]
        : [
            PolygonLayer(
              polygons: data!.polygons
                  .map(
                    (polygon) => Polygon(
                      points: polygon.points,
                      holePointsList: polygon.holes,
                      color: polygonFillColor,
                      borderColor: polygonBorderColor,
                      borderStrokeWidth: polygonBorderWidth,
                    ),
                  )
                  .toList(),
            ),
          ];

    return Stack(
      children: [
        ...polygonWidgets,
        ...polylineWidgets,
      ],
    );
  }
}

class GeoLayerTogglePanel extends StatelessWidget {
  final bool showBoundaryMedan;
  final bool showBoundaryDeliSerdang;
  final bool isLoading;
  final ValueChanged<bool> onBoundaryMedanChanged;
  final ValueChanged<bool> onBoundaryDeliSerdangChanged;

  const GeoLayerTogglePanel({
    super.key,
    required this.showBoundaryMedan,
    required this.showBoundaryDeliSerdang,
    required this.isLoading,
    required this.onBoundaryMedanChanged,
    required this.onBoundaryDeliSerdangChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 260,
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
                    Icons.layers_rounded,
                    size: 18,
                    color: AppTheme.textPrimary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Legenda & Layer Peta',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary(context),
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
              const SizedBox(height: 10),
              Text(
                'Atur layer utama dan lihat arti warna polygon serta garis yang muncul di peta.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              _buildToggleRow(
                'Batas Kota Medan',
                showBoundaryMedan,
                onBoundaryMedanChanged,
              ),
              _buildToggleRow(
                'Batas Deli Serdang',
                showBoundaryDeliSerdang,
                onBoundaryDeliSerdangChanged,
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: AppTheme.border(context).withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'Legenda Warna',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),
              _buildLegendRow(
                context,
                label: 'Batas Kota Medan',
                swatch: const Color(0xFFF59E0B),
                fill: const Color(0x14F59E0B),
              ),
              _buildLegendRow(
                context,
                label: 'Batas Deli Serdang',
                swatch: const Color(0xFF10B981),
                fill: const Color(0x1410B981),
              ),
              _buildLegendRow(
                context,
                label: 'Semua Kecamatan',
                swatch: isDark
                    ? const Color(0xFF7DD3FC)
                    : const Color(0xFF0284C7),
                fill: isDark
                    ? const Color(0x2438BDF8)
                    : const Color(0x1838BDF8),
              ),
              _buildLegendRow(
                context,
                label: 'Semua Kelurahan / Desa',
                swatch: const Color(0xFF7C3AED),
                fill: isDark
                    ? const Color(0x227C3AED)
                    : const Color(0x167C3AED),
              ),
              _buildLegendRow(
                context,
                label: 'Wilayah Filter Aktif',
                swatch: isDark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFEA580C),
                fill: isDark
                    ? const Color(0x24F97316)
                    : const Color(0x18EA580C),
              ),
              _buildLegendRow(
                context,
                label: 'Jalan Wilayah Aktif',
                swatch: const Color(0xFF1D4ED8),
                isLine: true,
              ),
              _buildLegendRow(
                context,
                label: 'Rute Navigasi',
                swatch: AppTheme.routeColor,
                isLine: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildLegendRow(
    BuildContext context, {
    required String label,
    required Color swatch,
    Color? fill,
    bool isLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 18,
            decoration: BoxDecoration(
              color: isLine ? Colors.transparent : (fill ?? swatch),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: swatch,
                width: isLine ? 2.6 : 1.8,
              ),
            ),
            child: isLine
                ? Center(
                    child: Container(
                      height: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: swatch,
                            width: 2.6,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
