import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/google_logo.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/layout/responsive_context.dart';
import '../../../../core/layout/two_pane_layout.dart';
import '../../../../core/widgets/beatter_scaffold.dart';
import '../../../../core/widgets/decorative_glow_background.dart';
import '../../../admin/presentation/pages/admin_dashboard.dart';
import '../../../music/presentation/navigation/main_navigation_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();

  UserRole _selectedRole = UserRole.user;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Password quality for new accounts: ≥8 chars with upper, lower and digit.
  static String? _passwordQualityError(String value) {
    if (value.length < 8) return 'Minimo 8 caratteri';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Serve almeno una maiuscola';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Serve almeno una minuscola';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Serve almeno un numero';
    return null;
  }

  // Every role gets its own accent so the two login paths are visually
  // distinct at a glance, not just distinguished by their label text.
  Color _roleColor(UserRole role) =>
      role == UserRole.admin ? AppColors.secondary : AppColors.primary;

  void _navigateToHome(UserSession session) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            session.role == UserRole.admin
            ? const AdminDashboard()
            : const MainNavigationShell(initialTab: AppTab.home),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isRegisterMode && _selectedRole == UserRole.user) {
      try {
        final session = await AuthService.register(
          email: _emailController.text,
          password: _passwordController.text,
          nickname: _nicknameController.text,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        _navigateToHome(session);
      } on AppFailure catch (failure) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = failure is AuthFailure &&
                  failure.code == 'email-already-in-use'
              ? 'Esiste già un account con questa email. Prova ad accedere.'
              : failure.message;
        });
      }
      return;
    }

    final session = await AuthService.login(
      email: _emailController.text,
      password: _passwordController.text,
      expectedRole: _selectedRole,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (session != null) {
      _navigateToHome(session);
    } else {
      setState(() {
        _errorMessage = _selectedRole == UserRole.admin
            ? 'Accesso amministratore fallito. Controlla le credenziali.'
            : 'Credenziali non valide. Riprova o crea un account.';
      });
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password dimenticata?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Inserisci la tua email: ti invieremo un link per reimpostare la password.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Indirizzo Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (!email.contains('@')) return;
              try {
                await AuthService.sendPasswordReset(email);
              } on AppFailure {
                // Don't reveal whether the address exists (enumeration).
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Invia link'),
          ),
        ],
      ),
    );

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se l\'email è registrata riceverai un link per reimpostare la password.',
          ),
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await AuthService.loginWithGoogle();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateToHome(session);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // A dismissed account picker is not an error worth showing.
        _errorMessage = failure is AuthFailure && failure.isCancelled
            ? null
            : failure.message;
      });
    }
  }

  void _changeRole(UserRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _isRegisterMode = false;
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _nicknameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BeatterScaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: DecorativeGlowBackground(
          child: SafeArea(
            child: TwoPaneLayout(
              portrait: (context) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBranding(context),
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildFormCard(context),
                      ],
                    ),
                  ),
                ),
              ),
              landscapePrimary: (context) => Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBranding(context),
                ),
              ),
              landscapeSecondary: (context) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFormCard(context),
                      ],
                    ),
                  ),
                ),
              ),
              primaryFlex: 0.4,
              secondaryFlex: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double logoSize = context.responsive(portrait: 60.0, landscape: 44.0);
    final double titleSize = context.responsive(
      portrait: 40.0,
      landscape: 28.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/logos/logo_beatter.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Text(
              'Beatter',
              style: textTheme.displaySmall?.copyWith(
                fontSize: titleSize,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sintonizza il tuo mondo',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double padding = context.responsive(portrait: 28.0, landscape: 18.0);
    final Color roleColor = _roleColor(_selectedRole);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: AppTheme.glassCardDecoration(borderRadius: AppRadius.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Tab Switcher (Segmented Selector)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildRoleTab(
                          title: 'Utente',
                          role: UserRole.user,
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      Expanded(
                        child: _buildRoleTab(
                          title: 'Admin',
                          role: UserRole.admin,
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Fields Label
                Text(
                  _selectedRole == UserRole.admin
                      ? 'Pannello di Controllo Admin'
                      : _isRegisterMode
                      ? 'Crea il tuo account'
                      : 'Accedi come Ascoltatore',
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Nickname (registration only) — unique handle in the app.
                if (_isRegisterMode && _selectedRole == UserRole.user) ...[
                  TextFormField(
                    controller: _nicknameController,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Nickname',
                      helperText: '3-24 caratteri: lettere, numeri e _',
                      prefixIcon:
                          Icon(Icons.alternate_email_rounded, color: roleColor),
                    ),
                    validator: (value) {
                      final nickname = value?.trim() ?? '';
                      if (nickname.isEmpty) return 'Scegli un nickname';
                      if (!AuthService.nicknameFormat.hasMatch(nickname)) {
                        return 'Solo lettere, numeri e _ (3-24 caratteri)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm + 6),
                ],

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Indirizzo Email',
                    prefixIcon: Icon(Icons.email_outlined, color: roleColor),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci la tua email';
                    }
                    if (!value.contains('@')) {
                      return 'Inserisci un indirizzo email valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm + 6),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: roleColor,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: _obscurePassword
                          ? 'Mostra password'
                          : 'Nascondi password',
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la password';
                    }
                    if (_isRegisterMode && _selectedRole == UserRole.user) {
                      return _passwordQualityError(value);
                    }
                    if (value.length < 6) {
                      return 'La password deve avere almeno 6 caratteri';
                    }
                    return null;
                  },
                ),

                // Confirm password (registration) / reset link (login).
                if (_isRegisterMode && _selectedRole == UserRole.user) ...[
                  const SizedBox(height: AppSpacing.sm + 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Conferma Password',
                      prefixIcon:
                          Icon(Icons.lock_person_outlined, color: roleColor),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Le password non coincidono';
                      }
                      return null;
                    },
                  ),
                ] else if (_selectedRole == UserRole.user)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      child: Text(
                        'Password dimenticata?',
                        style: textTheme.bodySmall?.copyWith(color: roleColor),
                      ),
                    ),
                  ),

                // Error Message Alert
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.error,
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: roleColor),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _selectedRole == UserRole.admin
                              ? 'ACCEDI COME ADMIN'
                              : _isRegisterMode
                              ? 'REGISTRATI'
                              : 'ACCEDI ORA',
                        ),
                ),

                // Alternative sign-in paths (user role only).
                if (_selectedRole == UserRole.user) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          'oppure',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    // Monochrome Google identity "G" per sign-in branding.
                    icon: const GoogleLogo(
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    label: const Text('Continua con Google'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _errorMessage = null;
                            }),
                    child: Text(
                      _isRegisterMode
                          ? 'Hai già un account? Accedi'
                          : 'Non hai un account? Registrati',
                      style: textTheme.bodySmall?.copyWith(color: roleColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab({
    required String title,
    required UserRole role,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    final Color color = _roleColor(role);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        onTap: () => _changeRole(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
