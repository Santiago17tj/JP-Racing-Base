import 'package:flutter/material.dart';

/// La placa como la de una moto en Colombia: fondo amarillo, letras negras.
/// Se reconoce de un vistazo en una lista de órdenes.
class PlacaMoto extends StatelessWidget {
  final String placa;
  final double tamano;

  const PlacaMoto(this.placa, {super.key, this.tamano = 14});

  static const _amarillo = Color(0xFFF2C400);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: tamano * 0.5, vertical: tamano * 0.14),
      decoration: BoxDecoration(
        color: _amarillo,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        placa.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black,
                  fontSize: tamano,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  height: 1.15,
                ) ??
            TextStyle(
                color: Colors.black,
                fontSize: tamano,
                fontWeight: FontWeight.w800),
      ),
    );
  }
}
