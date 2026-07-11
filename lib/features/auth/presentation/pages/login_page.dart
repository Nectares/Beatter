import 'dart:ui';
import 'package:flutter/material.dart';
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

  UserRole _selectedRole = UserRole.user;
  bool _isLoading = false;
  bool _obscurePassword = true;
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
    _animationController.dispose();
    super.dispose();
  }

  // Every role gets its own accent so the two login paths are visually
  // distinct at a glance, not just distinguished by their label text.
  Color _roleColor(UserRole role) =>
      role == UserRole.admin ? AppColors.secondary : AppColors.primary;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
      // Navigate based on role
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
    } else {
      setState(() {
        _errorMessage = _selectedRole == UserRole.admin
            ? 'Accesso amministratore fallito. Controlla le credenziali o il codice di accesso.'
            : 'Credenziali non valide. Prova user@beatter.com / password123';
      });
    }
  }

  void _changeRole(UserRole role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _emailController.clear();
      _passwordController.clear();
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
                        const SizedBox(height: AppSpacing.xl),
                        _buildCredentialsHelper(context),
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
                        const SizedBox(height: AppSpacing.lg),
                        _buildCredentialsHelper(context),
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
                  _selectedRole == UserRole.user
                      ? 'Accedi come Ascoltatore'
                      : 'Pannello di Controllo Admin',
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

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
                    if (value.length < 6) {
                      return 'La password deve avere almeno 6 caratteri';
                    }
                    return null;
                  },
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
                              : 'ACCEDI ORA',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsHelper(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Color roleColor = _roleColor(_selectedRole);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundEnd,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: roleColor),
              const SizedBox(width: AppSpacing.xs),
              Text('Credenziali Demo:', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            _selectedRole == UserRole.user
                ? 'Utente: user@beatter.com / password123'
                : 'Admin: admin@beatter.com / admin123',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
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
