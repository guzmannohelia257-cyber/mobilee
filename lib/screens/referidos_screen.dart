import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_emergencias/theme/app_colors.dart';

import '../services/referido_service.dart';

/// Código de referido (único y permanente) + canje de un código ajeno. Al
/// canjear se generan 2 cupones: 10% para el dueño del código, 5% para quien
/// canjea. Los cupones no caducan; se usan al confirmar el taller.
class ReferidosScreen extends StatefulWidget {
  const ReferidosScreen({super.key});

  @override
  State<ReferidosScreen> createState() => _ReferidosScreenState();
}

class _ReferidosScreenState extends State<ReferidosScreen> {
  final ReferidoService _service = ReferidoService();

  bool _cargando = true;
  String? _error;
  String _codigo = '';
  int _totalReferidos = 0;
  int _cuponesDisponibles = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = await _service.miCodigo();
    if (!mounted) return;

    if (resultado['success'] != true) {
      setState(() {
        _error = resultado['error']?.toString() ?? 'No se pudo cargar tu código';
        _cargando = false;
      });
      return;
    }

    setState(() {
      _codigo = resultado['codigo'] as String;
      _totalReferidos = resultado['total_referidos'] as int;
      _cuponesDisponibles = resultado['cupones_disponibles'] as int;
      _cargando = false;
    });
  }

  Future<void> _copiarCodigo() async {
    await Clipboard.setData(ClipboardData(text: _codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado al portapapeles')),
    );
  }

  Future<void> _abrirDialogoCanjear() async {
    final ctrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresar código de referido'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ej. ABC12345'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    final codigo = ctrl.text.trim();
    if (codigo.isEmpty) return;

    final resultado = await _service.canjear(codigo);
    if (!mounted) return;

    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['mensaje']?.toString() ?? '¡Código canjeado!'),
          backgroundColor: AppColors.forest,
        ),
      );
      await _cargar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['error']?.toString() ?? 'No se pudo canjear el código'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Referidos'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildCodigoCard(),
                      const SizedBox(height: 20),
                      _buildStats(),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _abrirDialogoCanjear,
                        icon: const Icon(Icons.redeem_outlined),
                        label: const Text('Ingresar código de referido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: const BorderSide(color: AppColors.brand),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Solo puedes canjear un código una vez. Los cupones no '
                        'caducan: los usas cuando quieras al elegir taller.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.brand),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildCodigoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TU CÓDIGO DE REFERIDO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _codigo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Compártelo: tú ganas un cupón por cada persona que lo use',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copiarCodigo,
              icon: const Icon(Icons.copy_outlined, color: Colors.white),
              label: const Text('Copiar código', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icono: Icons.people_alt_outlined,
            valor: '$_totalReferidos',
            label: 'Personas referidas',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icono: Icons.confirmation_number_outlined,
            valor: '$_cuponesDisponibles',
            label: 'Cupones disponibles',
          ),
        ),
      ],
    );
  }

  Widget _statCard({required IconData icono, required String valor, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.brand, size: 22),
          const SizedBox(height: 8),
          Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}
