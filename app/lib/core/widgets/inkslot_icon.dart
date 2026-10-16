import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Los 26 iconos de trazo del prototipo (`assets/iconos`), 24 px, `currentColor`.
enum InkSlotIcons {
  alerta('alerta'),
  avanzar('avanzar'),
  bajar('bajar'),
  calendarioAgregar('calendario-agregar'),
  calendarioAlerta('calendario-alerta'),
  calendarioCheck('calendario-check'),
  calendarioVacio('calendario-vacio'),
  calendario('calendario'),
  camaraSocial('camara-social'),
  cancelado('cancelado'),
  candado('candado'),
  cerrar('cerrar'),
  check('check'),
  compartir('compartir'),
  enlace('enlace'),
  flechaDerecha('flecha-derecha'),
  inicio('inicio'),
  mas('mas'),
  menos('menos'),
  mensaje('mensaje'),
  relojArena('reloj-arena'),
  reloj('reloj'),
  sinConexion('sin-conexion'),
  sincronizar('sincronizar'),
  subir('subir'),
  volver('volver');

  const InkSlotIcons(this.file);

  final String file;
  String get asset => 'assets/assets/icons/$file.svg';
}

class InkSlotIcon extends StatelessWidget {
  const InkSlotIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth,
    this.semanticLabel,
  });

  final InkSlotIcons icon;
  final double size;
  final Color? color;

  /// Reservado: el trazo viene del SVG (1.8 en 24 px).
  final double? strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Colors.white;
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
