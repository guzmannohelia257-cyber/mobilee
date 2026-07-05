import 'dart:convert';

import 'auth_service.dart';

class MovimientoModel {
  final int idMovimiento;
  final String tipo; // 'credito' | 'debito'
  final String motivo;
  final double monto;
  final double saldoResultante;
  final String? referencia;
  final String? descripcion;
  final DateTime createdAt;

  MovimientoModel({
    required this.idMovimiento,
    required this.tipo,
    required this.motivo,
    required this.monto,
    required this.saldoResultante,
    this.referencia,
    this.descripcion,
    required this.createdAt,
  });

  bool get esCredito => tipo == 'credito';

  factory MovimientoModel.fromJson(Map<String, dynamic> j) => MovimientoModel(
        idMovimiento: j['id_movimiento'] as int,
        tipo: j['tipo'] as String,
        motivo: j['motivo'] as String,
        monto: (j['monto'] as num).toDouble(),
        saldoResultante: (j['saldo_resultante'] as num).toDouble(),
        referencia: j['referencia'] as String?,
        descripcion: j['descripcion'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Servicio de la billetera digital (cartera virtual). Solo entra dinero
/// (recarga con tarjeta, propia o de otra persona); no existe retiro.
class BilleteraService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> saldo() async {
    try {
      final response = await _authService.authenticatedRequest('GET', '/billetera');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'saldo': (data['saldo'] as num).toDouble()};
      }
      return {'success': false, 'error': 'Error al obtener el saldo (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> movimientos({int limit = 50}) async {
    try {
      final response = await _authService.authenticatedRequest(
        'GET',
        '/billetera/movimientos?limit=$limit',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((j) => MovimientoModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return {'success': true, 'items': items};
      }
      return {'success': false, 'error': 'Error al obtener movimientos (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Crea el PaymentIntent para recargar. Si [emailDestino] viene, el crédito
  /// va a la billetera de ese cliente (recarga a otra persona); el pagador
  /// (usuario autenticado) paga con su propia tarjeta.
  Future<Map<String, dynamic>> recargar({
    required double monto,
    String? emailDestino,
  }) async {
    try {
      final body = <String, dynamic>{'monto': monto};
      if (emailDestino != null && emailDestino.trim().isNotEmpty) {
        body['email_destino'] = emailDestino.trim();
      }
      final response = await _authService.authenticatedRequest(
        'POST',
        '/billetera/recargar',
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'client_secret': data['client_secret'] as String,
          'payment_intent_id': data['payment_intent_id'] as String,
          'monto_centavos': data['monto_centavos'] as int,
          'destino_nombre': data['destino_nombre'] as String?,
        };
      }
      return {'success': false, 'error': _parseError(response.body)};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> confirmarRecarga(String paymentIntentId) async {
    try {
      final response = await _authService.authenticatedRequest(
        'POST',
        '/billetera/recargar-confirmar',
        body: {'payment_intent_id': paymentIntentId},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'estado': data['estado']};
      }
      return {'success': false, 'error': _parseError(response.body)};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? 'Error desconocido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Error desconocido';
    }
  }
}
