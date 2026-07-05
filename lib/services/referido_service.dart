import 'dart:convert';

import 'auth_service.dart';

class CuponModel {
  final int idCupon;
  final String tipo; // 'referente' | 'nuevo'
  final int porcentaje;
  final String estado; // 'disponible' | 'usado'

  CuponModel({
    required this.idCupon,
    required this.tipo,
    required this.porcentaje,
    required this.estado,
  });

  factory CuponModel.fromJson(Map<String, dynamic> j) => CuponModel(
        idCupon: j['id_cupon'] as int,
        tipo: j['tipo'] as String,
        porcentaje: j['porcentaje'] as int,
        estado: j['estado'] as String,
      );
}

/// Cupones de referidos: código único y permanente para compartir. Al
/// canjearse un código se generan 2 cupones (10% dueño / 5% quien canjea),
/// sin vigencia — se usan en cualquier momento al confirmar el taller.
class ReferidoService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> miCodigo() async {
    try {
      final response = await _authService.authenticatedRequest('GET', '/referidos/mi-codigo');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'codigo': data['codigo'] as String,
          'total_referidos': data['total_referidos'] as int,
          'cupones_disponibles': data['cupones_disponibles'] as int,
        };
      }
      return {'success': false, 'error': 'Error al obtener el código (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> canjear(String codigo) async {
    try {
      final response = await _authService.authenticatedRequest(
        'POST',
        '/referidos/canjear',
        body: {'codigo': codigo.trim()},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'mensaje': data['mensaje'] as String?};
      }
      return {'success': false, 'error': _parseError(response.body)};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> misCupones() async {
    try {
      final response = await _authService.authenticatedRequest('GET', '/cupones');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((j) => CuponModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return {'success': true, 'items': items};
      }
      return {'success': false, 'error': 'Error al obtener cupones (${response.statusCode})'};
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
