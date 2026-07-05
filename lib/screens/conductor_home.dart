import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/incidente_service.dart';
import '../services/taller_service.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/vehiculo_service.dart';
import '../services/offline/wizard_draft_service.dart';
import '../services/tour_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_badge.dart';
import '../models/incidente.dart';
import 'reportar_emergencia_screen.dart';
import 'seleccionar_taller_screen.dart';
import 'subir_evidencia_screen.dart';
import 'historial_emergencias_screen.dart';

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  final AuthService _authService = AuthService();
  String _userName = '';
  bool _isLoading = true;
  IncidenteDetalle? _incidenteActivo;
  bool _cargandoIncidente = true;
  final GlobalKey _keyBotonSolicitar = GlobalKey();
  bool _mostrarSaltarTour = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cargarIncidenteActivo();
    // Tras abrir, si hay un reporte a medias, ofrecer reanudarlo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReporteEnCurso());
  }

  /// Dispara el spotlight del tour SOLO si: (a) no hay incidente activo (el
  /// botón "Solicitar asistencia" existe y se está mostrando) y (b) el tour
  /// aún no fue visto. Se llama al final de `_cargarIncidenteActivo()`
  /// (después de su `setState`), nunca desde `initState` directo, porque
  /// `_incidenteActivo` recién se resuelve tras la llamada async al backend.
  Future<void> _dispararTourSiCorresponde() async {
    if (_incidenteActivo != null) return; // sin botón que resaltar hoy
    final visto = await TourService().yaVisto();
    if (visto || !mounted) return;
    setState(() => _mostrarSaltarTour = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ShowCaseWidget.of(context).startShowCase([_keyBotonSolicitar]);
    });
  }

  Future<void> _saltarTour() async {
    await TourService().saltarTour();
    if (!mounted) return;
    setState(() => _mostrarSaltarTour = false);
    ShowCaseWidget.of(context).dismiss();
  }

  /// Si quedo un reporte sin terminar, pregunta si continuar y reanuda el paso.
  Future<void> _checkReporteEnCurso() async {
    final draft = await WizardDraftService().cargar();
    if (draft == null || !mounted) return;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reporte sin terminar'),
        content: const Text(
          'Tienes un reporte de emergencia a medias. '
          '¿Quieres continuar donde lo dejaste?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (continuar == true) {
      await _reanudarReporte(draft);
    } else if (continuar == false) {
      if (draft.idIncidente != null) {
        IncidenteService().descartarBorrador(draft.idIncidente!);
      }
      await WizardDraftService().limpiar();
    }
    // Si cerro el dialogo sin elegir, el draft se conserva para la proxima.
  }

  Future<void> _reanudarReporte(WizardDraft d) async {
    // Paso 3: el borrador ya existe y la categoria esta lista -> elegir taller.
    if (d.paso == 3 &&
        d.idIncidente != null &&
        d.categoriaId != null &&
        d.latitud != null &&
        d.longitud != null) {
      try {
        final categoria = await TallerService().getCategoria(d.categoriaId!);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeleccionarTallerScreen(
              categoria: categoria,
              latitud: d.latitud!,
              longitud: d.longitud!,
              idIncidente: d.idIncidente,
            ),
          ),
        );
      } catch (_) {
        await WizardDraftService().limpiar();
      }
      return;
    }

    // Paso 2: pantalla de evidencias con los datos del formulario.
    if (d.paso == 2 &&
        d.idVehiculo != null &&
        d.descripcion != null &&
        d.latitud != null &&
        d.longitud != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubirEvidenciaScreen(
            idVehiculo: d.idVehiculo,
            descripcionUsuario: d.descripcion,
            latitud: d.latitud,
            longitud: d.longitud,
            idempotencyKey: d.idempotencyKey,
            evidenciasIniciales: d.evidencias,
          ),
        ),
      );
      return;
    }

    // Paso 1 (o datos insuficientes): reabrir el formulario con lo que haya.
    final vehiculos = await _obtenerVehiculos();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        // ShowCaseWidget propio: ReportarEmergenciaScreen dispara su propio
        // spotlight en initState() y necesita un ancestro; esta pantalla se
        // llega vía MaterialPageRoute directo, NO por la ruta nombrada
        // '/reportar-emergencia' (esa la usa historial_emergencias_screen.dart).
        builder: (_) => ShowCaseWidget(
          onFinish: () => TourService().marcarVisto(),
          builder: (_) => ReportarEmergenciaScreen(
            vehiculos: vehiculos ?? const [],
            idVehiculoInicial: d.idVehiculo,
            descripcionInicial: d.descripcion,
            latitudInicial: d.latitud,
            longitudInicial: d.longitud,
            ubicacionTextoInicial: d.ubicacionTexto,
            idempotencyKey: d.idempotencyKey,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _obtenerVehiculos() async {
    final resultado = await VehiculoService().listarMisVehiculos();
    if (resultado['success'] == true) {
      return List<Map<String, dynamic>>.from(
        (resultado['vehiculos'] as List? ?? []).map(
          (v) => Map<String, dynamic>.from(v as Map),
        ),
      );
    }
    return null;
  }

  Future<void> _loadUserData() async {
    final name = await _authService.getUserName();

    if (!mounted) return;
    setState(() {
      _userName = name ?? 'Conductor';
      _isLoading = false;
    });
  }

  /// Carga el incidente activo del cliente (solo puede haber uno a la vez).
  /// Si el backend tarda/falla, queda en null y el home muestra "Reportar".
  Future<void> _cargarIncidenteActivo() async {
    final res = await IncidenteService().listarMisIncidencias();
    if (!mounted) return;
    IncidenteDetalle? activo;
    if (res['success'] == true) {
      final List<IncidenteDetalle> lista = res['incidencias'] ?? [];
      for (final inc in lista) {
        if (_esActivo(inc)) {
          activo = inc;
          break;
        }
      }
    }
    setState(() {
      _incidenteActivo = activo;
      _cargandoIncidente = false;
    });
    _dispararTourSiCorresponde();
  }

  /// True si el incidente sigue en curso (no atendido/cancelado/borrador).
  bool _esActivo(IncidenteDetalle inc) {
    final nombre = (inc.estado?['nombre'] as String?)?.toLowerCase() ?? '';
    if (nombre == 'borrador' || nombre == 'atendido' || nombre == 'cancelado') {
      return false;
    }
    if (nombre.isNotEmpty) return true;
    return inc.idEstado == 1 || inc.idEstado == 2;
  }

  void _abrirIncidente(IncidenteDetalle inc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HistorialEmergenciasScreen(abrirDetalle: inc.idIncidente),
      ),
    ).then((_) {
      if (mounted) _cargarIncidenteActivo();
    });
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ').where((s) => s.isNotEmpty);
    return parts.isEmpty ? fullName : parts.first;
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Volverás a la pantalla de inicio. Tu información local se mantiene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _reportarEmergencia() async {
    final vehiculoService = VehiculoService();
    final resultado = await vehiculoService.listarMisVehiculos();
    if (!mounted) return;

    if (resultado['success'] == true) {
      final vehiculos = List<Map<String, dynamic>>.from(
        (resultado['vehiculos'] as List? ?? []).map(
          (v) => Map<String, dynamic>.from(v as Map),
        ),
      );

      // Si los vehiculos vienen de la cache (sin conexion), avisamos que la
      // emergencia se enviara al reconectar, pero permitimos empezar igual.
      if (resultado['offline'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexion: usando tus vehiculos guardados. La emergencia se enviara al reconectar.',
            ),
          ),
        );
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          // ShowCaseWidget propio: este es el camino REAL que sigue el botón
          // "Solicitar asistencia" (Paso 1 del tour). ReportarEmergenciaScreen
          // dispara su propio spotlight en initState() y necesita un
          // ShowCaseWidget ancestro — no llega por la ruta nombrada
          // '/reportar-emergencia' de main.dart, así que hay que envolverla
          // aquí explícitamente o ShowCaseWidget.of(context) lanza una
          // excepción ("Please provide a context that has ShowCaseWidget").
          builder: (context) => ShowCaseWidget(
            onFinish: () => TourService().marcarVisto(),
            builder: (context) => ReportarEmergenciaScreen(vehiculos: vehiculos),
          ),
        ),
      );
      if (mounted) _cargarIncidenteActivo();
    } else {
      // resultado['error'] ya es un mensaje amable (no expone excepciones).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['error'] ?? 'Error al cargar vehículos'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 22),
                      _buildGreeting(),
                      const SizedBox(height: 22),
                      _incidenteActivo != null
                          ? _buildActiveIncidentCard(_incidenteActivo!)
                          : _buildEmergencyCard(),
                      const SizedBox(height: 16),
                      _buildFeatureCards(),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Cerrar sesión'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_mostrarSaltarTour)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton(
                          onPressed: _saltarTour,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.inkMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: const Text('Saltar'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 15, color: AppColors.brand),
              SizedBox(width: 6),
              Text(
                'Ubicación actual',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSubtle,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const ConnectionBadge(),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.notifications_none_rounded,
          onTap: () => Navigator.pushNamed(context, '/notificaciones'),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/perfil'),
          child: _AvatarChip(initials: _initials(_userName), size: 46),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_saludo()},',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Hola, ${_firstName(_userName)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Todo en orden para hoy. Estamos aquí si nos necesitas.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.inkSubtle,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brand.withValues(alpha: 0.14),
            ),
            child: const Center(
              child: Icon(Icons.sos_rounded, color: AppColors.brand, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Emergencia SOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.brandInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Documenta el incidente y solicita asistencia de inmediato. '
            'Asignaremos un técnico cercano en minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.inkSubtle,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Showcase(
              key: _keyBotonSolicitar,
              description: 'Toca aquí para pedir ayuda y documentar tu emergencia.',
              disposeOnTap: true,
              onTargetClick: () {
                _reportarEmergencia();
              },
              child: FilledButton.icon(
                onPressed: _reportarEmergencia,
                icon: const Icon(Icons.add_alert_rounded, size: 20),
                label: const Text('Solicitar asistencia'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveIncidentCard(IncidenteDetalle inc) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: AppColors.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC26849), Color(0xFF984B30)],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXl),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.emergency_share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MI INCIDENTE ACTIVO',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inc.getEstadoNombre(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _incidenteRow(
                  Icons.report_problem_outlined,
                  inc.getCategoriaNombre(),
                ),
                const SizedBox(height: 8),
                _incidenteRow(
                  Icons.directions_car_outlined,
                  '${inc.getMarca()} · ${inc.getPlaca()}',
                ),
                const SizedBox(height: 8),
                _incidenteRow(Icons.schedule_outlined, inc.getFechaFormato()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _abrirIncidente(inc),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Ver seguimiento'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _cargandoIncidente
                          ? null
                          : _cargarIncidenteActivo,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.inkSubtle,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidenteRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSubtle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FeatureCard(
              icon: Icons.directions_car_outlined,
              accent: AppColors.slate,
              accentSoft: AppColors.slateSoft,
              title: 'Mis vehículos',
              hint: 'Registra y gestiona',
              cta: 'Gestionar',
              onTap: () => Navigator.pushNamed(context, '/mis-vehiculos'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _FeatureCard(
              icon: Icons.receipt_long_outlined,
              accent: AppColors.indigo,
              accentSoft: AppColors.indigoSoft,
              title: 'Historial',
              hint: 'Incidentes y viajes',
              cta: 'Ver reportes',
              onTap: () =>
                  Navigator.pushNamed(context, '/historial-emergencias'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                active: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'Historial',
                onTap: () =>
                    Navigator.pushNamed(context, '/historial-emergencias'),
              ),
              _NavItem(
                icon: Icons.directions_car_outlined,
                label: 'Vehículos',
                onTap: () => Navigator.pushNamed(context, '/mis-vehiculos'),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Facturas',
                onTap: () => Navigator.pushNamed(context, '/mis-pagos'),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                onTap: () => Navigator.pushNamed(context, '/perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final String initials;
  final double size;
  const _AvatarChip({required this.initials, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC26849), Color(0xFF984B30)],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final String title;
  final String hint;
  final String cta;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.title,
    required this.hint,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: AppColors.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    cta,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.brand : AppColors.inkMuted;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 23, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
