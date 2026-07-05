import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class MensajeModel {
  final int idMensaje;
  final int idIncidente;
  final int? idUsuario;
  final int? idTaller;
  final String contenido; // SIEMPRE el texto original
  final bool leido;
  final DateTime createdAt;

  // Traducción al idioma del receptor (feature turistas).
  final String? contenidoTraducido;
  final String? idiomaOrigen;
  final String? idiomaDestino;
  final bool traducido;

  MensajeModel({
    required this.idMensaje,
    required this.idIncidente,
    this.idUsuario,
    this.idTaller,
    required this.contenido,
    required this.leido,
    required this.createdAt,
    this.contenidoTraducido,
    this.idiomaOrigen,
    this.idiomaDestino,
    this.traducido = false,
  });

  factory MensajeModel.fromJson(Map<String, dynamic> j) => MensajeModel(
        idMensaje: j['id_mensaje'] as int,
        idIncidente: j['id_incidente'] as int,
        idUsuario: j['id_usuario'] as int?,
        idTaller: j['id_taller'] as int?,
        contenido: j['contenido'] as String,
        leido: j['leido'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
        contenidoTraducido: j['contenido_traducido'] as String?,
        idiomaOrigen: j['idioma_origen'] as String?,
        idiomaDestino: j['idioma_destino'] as String?,
        traducido: (j['traducido'] as bool?) ?? false,
      );
}

class MensajesService {
  static const String _baseUrl = ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<String?> _token() => _authService.getToken();

  Future<List<MensajeModel>> listar(int idIncidente) async {
    final token = await _token();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/mensajes/$idIncidente'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final lista = jsonDecode(response.body) as List<dynamic>;
      return lista.map((e) => MensajeModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    debugPrint('[MensajesService] listar error ${response.statusCode}');
    return [];
  }

  Future<MensajeModel?> enviar(int idIncidente, String contenido) async {
    final token = await _token();
    if (token == null) return null;

    final response = await http.post(
      Uri.parse('$_baseUrl/mensajes/$idIncidente'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'contenido': contenido}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      return MensajeModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    debugPrint('[MensajesService] enviar error ${response.statusCode}: ${response.body}');
    return null;
  }
}
