import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_emergencias/theme/app_colors.dart';

import '../services/billetera_service.dart';

/// Billetera digital (cartera virtual): se recarga con tarjeta (propia o de
/// otra persona) y solo se gasta pagando servicios dentro de la app. No hay
/// opción de retiro.
class BilleteraScreen extends StatefulWidget {
  const BilleteraScreen({super.key});

  @override
  State<BilleteraScreen> createState() => _BilleteraScreenState();
}

class _BilleteraScreenState extends State<BilleteraScreen> {
  final BilleteraService _service = BilleteraService();

  bool _cargando = true;
  String? _error;
  double _saldo = 0;
  List<MovimientoModel> _movimientos = [];
  bool _procesandoRecarga = false;

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

    final saldoRes = await _service.saldo();
    final movRes = await _service.movimientos();

    if (!mounted) return;

    if (saldoRes['success'] != true) {
      setState(() {
        _error = saldoRes['error']?.toString() ?? 'No se pudo cargar la billetera';
        _cargando = false;
      });
      return;
    }

    setState(() {
      _saldo = saldoRes['saldo'] as double;
      _movimientos = movRes['success'] == true
          ? List<MovimientoModel>.from(movRes['items'] ?? [])
          : [];
      _cargando = false;
    });
  }

  String _monto(double monto) => NumberFormat.currency(
        locale: 'es_BO',
        symbol: 'Bs ',
        decimalDigits: 2,
      ).format(monto);

  String _fecha(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());

  String _motivoLabel(String motivo) {
    const labels = {
      'recarga_tarjeta': 'Recarga con tarjeta',
      'recarga_recibida': 'Recarga recibida',
      'pago_servicio': 'Pago de servicio',
      'reverso': 'Reverso',
      'ajuste_admin': 'Ajuste',
    };
    return labels[motivo] ?? motivo;
  }

  Future<void> _abrirDialogoRecarga({bool paraOtro = false}) async {
    final montoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(paraOtro ? 'Recargar a otra persona' : 'Recargar con tarjeta'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (paraOtro) ...[
                const Text('Email del destinatario'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'correo@ejemplo.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa un email';
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v.trim())) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              const Text('Monto a recargar (USD)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Ej. 10'),
                validator: (v) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return 'Ingresa un monto válido';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final monto = double.parse(montoCtrl.text.trim());
    final email = paraOtro ? emailCtrl.text.trim() : null;
    await _procesarRecarga(monto: monto, emailDestino: email);
  }

  Future<void> _procesarRecarga({required double monto, String? emailDestino}) async {
    setState(() => _procesandoRecarga = true);

    try {
      final intentRes = await _service.recargar(monto: monto, emailDestino: emailDestino);
      if (!mounted) return;

      if (intentRes['success'] != true) {
        _mostrarError(intentRes['error']?.toString() ?? 'No se pudo iniciar la recarga');
        return;
      }

      final clientSecret = intentRes['client_secret'] as String;
      final paymentIntentId = intentRes['payment_intent_id'] as String;
      final destinoNombre = intentRes['destino_nombre'] as String?;

      final prefs = await SharedPreferences.getInstance();
      final nombreUsuario = prefs.getString('user_name');
      final emailUsuario = prefs.getString('user_email');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Flujo Emergencia',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            name: (nombreUsuario != null && nombreUsuario.isNotEmpty) ? nombreUsuario : null,
            email: (emailUsuario != null && emailUsuario.isNotEmpty) ? emailUsuario : null,
          ),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFFC26849)),
          ),
        ),
      );

      if (!mounted) return;
      await Stripe.instance.presentPaymentSheet();

      if (!mounted) return;
      final confirmRes = await _service.confirmarRecarga(paymentIntentId);
      if (!mounted) return;

      final mensaje = emailDestino != null && emailDestino.isNotEmpty
          ? 'Recarga enviada a ${destinoNombre ?? emailDestino}'
          : '¡Billetera recargada!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmRes['success'] == true ? mensaje : 'Recarga procesada'),
          backgroundColor: AppColors.forest,
        ),
      );
      await _cargar();
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code == FailureCode.Canceled) return;
      _mostrarError('Error al procesar la recarga: ${e.error.localizedMessage ?? e.error.message}');
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _procesandoRecarga = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi billetera'),
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
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSaldoCard(),
                      const SizedBox(height: 20),
                      _buildAcciones(),
                      const SizedBox(height: 24),
                      Text(
                        'HISTORIAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_movimientos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Aún no tienes movimientos',
                              style: TextStyle(color: AppColors.inkMuted),
                            ),
                          ),
                        )
                      else
                        ..._movimientos.map(_buildMovimientoTile),
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

  Widget _buildSaldoCard() {
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
            'SALDO DISPONIBLE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _monto(_saldo),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Úsalo para pagar tus servicios en la app',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _procesandoRecarga ? null : () => _abrirDialogoRecarga(paraOtro: false),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Recargar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _procesandoRecarga ? null : () => _abrirDialogoRecarga(paraOtro: true),
            icon: const Icon(Icons.person_add_alt_outlined),
            label: const Text('Recargar a otro'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: const BorderSide(color: AppColors.brand),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovimientoTile(MovimientoModel m) {
    final color = m.esCredito ? AppColors.forest : AppColors.danger;
    final signo = m.esCredito ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              m.esCredito ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _motivoLabel(m.motivo),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _fecha(m.createdAt),
                  style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                ),
                if (m.descripcion != null && m.descripcion!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      m.descripcion!,
                      style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$signo${_monto(m.monto)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}
