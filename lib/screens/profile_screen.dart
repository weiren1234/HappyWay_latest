import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/header_section.dart';
import '../routes/app_routes.dart';
import '../utils/validators.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: auth.user?.name ?? '');
    final emailController = TextEditingController(text: auth.user?.email ?? '');
    bool submitted = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.borderGlass(ctx)),
          ),
          title: Text('Edit Profile', style: TextStyle(color: AppColors.primaryText(ctx), fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text('Display Name', style: TextStyle(color: AppColors.secondaryText(ctx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: AppColors.primaryText(ctx)),
                    decoration: InputDecoration(
                      hintText: 'XXX',
                      hintStyle: TextStyle(color: AppColors.mutedText(ctx)),
                      filled: true,
                      fillColor: AppColors.inputFill(ctx),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.cyanAccent(ctx), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.inputBorder(ctx)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cyanAccent(ctx), width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
                      ),
                    ),
                    validator: Validators.validateDisplayName,
                  ),

                  const SizedBox(height: 16),

                  Text('Email Address', style: TextStyle(color: AppColors.secondaryText(ctx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.primaryText(ctx)),
                    decoration: InputDecoration(
                      hintText: 'xxxxx@gmail.com',
                      hintStyle: TextStyle(color: AppColors.mutedText(ctx)),
                      filled: true,
                      fillColor: AppColors.inputFill(ctx),
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.cyanAccent(ctx), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.inputBorder(ctx)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cyanAccent(ctx), width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
                      ),
                    ),
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Changing your email sends a confirmation link to the new address before updating.',
                    style: TextStyle(color: AppColors.mutedText(ctx), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(ctx))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => submitted = true);
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isSaving = true);

                      final currentName = auth.user?.name ?? '';

                      final currentEmail = Supabase.instance.client.auth.currentUser?.email
                          ?? auth.user?.email
                          ?? '';
                      final newName = nameController.text.trim();
                      final newEmail = emailController.text.trim();

                      final bool nameChanged = newName != currentName;
                      final bool emailChanged = newEmail.toLowerCase() != currentEmail.toLowerCase();

                      if (!nameChanged && !emailChanged) {
                        Navigator.pop(ctx);
                        return;
                      }

                      bool nameSuccess = true;
                      if (nameChanged) {
                        nameSuccess = await auth.updateDisplayName(newName);
                      }

                      String? emailMessage;
                      bool emailSuccess = true;
                      bool confirmationSent = false;
                      if (emailChanged) {
                        final emailRes = await auth.updateEmail(newEmail);
                        emailSuccess = emailRes.success;
                        emailMessage = emailRes.message;
                        confirmationSent = emailRes.confirmationSent;
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }

                      if (context.mounted) {
                        if (emailChanged) {

                          final displayMessage = confirmationSent
                              ? 'Confirmation email sent\nPlease check your new email address to confirm the change.'
                              : (emailMessage ?? (emailSuccess ? 'Email update requested.' : 'Failed to update email.'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                displayMessage,
                                style: TextStyle(color: AppColors.primaryText(context)),
                              ),
                              backgroundColor: emailSuccess ? AppColors.cardBg(context) : AppColors.dangerRed,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: confirmationSent ? 6 : 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: emailSuccess ? AppColors.cyanAccent(context) : AppColors.dangerRed,
                                ),
                              ),
                            ),
                          );
                        } else if (nameChanged) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                nameSuccess ? 'Display name updated successfully.' : 'Failed to update display name.',
                                style: TextStyle(color: AppColors.primaryText(context)),
                              ),
                              backgroundColor: nameSuccess ? AppColors.cardBg(context) : AppColors.dangerRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: nameSuccess ? AppColors.safeGreen : AppColors.dangerRed,
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.weatherBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDataSourcesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DataSourcesSheet(),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PrivacyDataSheet(),
    );
  }

  Future<void> _handleSignOut(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(ctx)),
        ),
        title: Text('Sign Out?', style: TextStyle(color: AppColors.primaryText(ctx))),
        content: Text(
          'Are you sure you want to sign out of your HappyWay account?',
          style: TextStyle(color: AppColors.secondaryText(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(ctx))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {

      final destProvider = Provider.of<DestinationProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      destProvider.clearUserData();
      tripProvider.clearUserData();

      await auth.logout(tripProvider: tripProvider);

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  String _buildInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'HW';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final n = parts[0];
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) {
        String selected = themeProvider.isDarkMode ? 'dark' : 'light';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBg(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.borderGlass(ctx)),
              ),
              title: Text(
                'Choose Theme',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText(ctx),
                ),
              ),
              content: RadioGroup<String>(
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selected = val);
                    themeProvider.setThemeMode(val);
                    auth.updateThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: Text(
                        'Dark',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryText(ctx),
                          fontWeight: selected == 'dark' ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Sleek dark glassmorphism',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(ctx)),
                      ),
                      value: 'dark',
                      activeColor: AppColors.accentCyan,
                    ),
                    RadioListTile<String>(
                      title: Text(
                        'Light',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryText(ctx),
                          fontWeight: selected == 'light' ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Crisp, modern light theme',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(ctx)),
                      ),
                      value: 'light',
                      activeColor: AppColors.weatherBlue,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppColors.cyanAccent(ctx))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final dest = Provider.of<DestinationProvider>(context);
    final trips = Provider.of<TripProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = auth.user;
    final prefs = auth.preferences;

    if (auth.isGuest) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const HeaderSection(
                  title: 'Profile',
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.weatherBlue, AppColors.accentCyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Guest',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primaryText(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to save trips and destinations.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.weatherBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyanAccent(context),
                      side: BorderSide(color: AppColors.cyanAccent(context)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 40),

                _SectionLabel(label: 'APP'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _TappableRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.accentCyan,
                        title: 'Data Sources & About',
                        subtitle: 'Official travel data and app information',
                        onTap: () => _showDataSourcesSheet(context),
                      ),
                      const Divider(height: 1, indent: 52),
                      _TappableRow(
                        icon: Icons.shield_outlined,
                        iconColor: AppColors.safeGreen,
                        title: 'Privacy & Data',
                        subtitle: 'How your information is handled',
                        onTap: () => _showPrivacySheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'HappyWay v1.2.0',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Smart Malaysian Travel Assistant',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      );
    }

    final bool isSessionActive = auth.isAuthenticated;
    final bool isLoading = auth.isLoading || (isSessionActive && user == null);
    final String? realName = user?.name;
    final String? realEmail = Supabase.instance.client.auth.currentUser?.email ?? user?.email;
    final String initials = _buildInitials(realName);
    final bool tripReminders = prefs?.tripRemindersEnabled ?? true;

    final int savedCount = dest.savedLocations.length;
    final int tripCount = trips.trips.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const HeaderSection(
                title: 'Profile & Settings',
                subtitle: 'Manage your account and travel preferences',
              ),
              const SizedBox(height: 20),

              if (isLoading)
                const _ProfileLoadingCard()
              else if (user == null)
                const _ProfileErrorCard()
              else
                _buildProfileCard(context, auth, initials, realName, realEmail),

              if (!isLoading && user != null && (savedCount > 0 || tripCount > 0)) ...[
                const SizedBox(height: 12),
                _buildStatsRow(context, savedCount, tripCount),
              ],

              const SizedBox(height: 28),

              _SectionLabel(label: 'ACCOUNT'),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [

                    _InfoRow(
                      icon: Icons.email_outlined,
                      iconColor: AppColors.accentCyan,
                      label: 'Email',
                      value: realEmail ?? '—',
                    ),
                    const Divider(height: 1, indent: 52),

                    _TappableRow(
                      icon: Icons.lock_outline_rounded,
                      iconColor: AppColors.weatherBlue,
                      title: 'Change Password',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'PREFERENCES'),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [

                    _SwitchRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: AppColors.safeGreen,
                      title: 'Trip Reminders',
                      subtitle: 'Show in-app reminders for upcoming trips',
                      value: tripReminders,
                      onChanged: (v) async {
                        final tripProvider = Provider.of<TripProvider>(context, listen: false);
                        final error = await auth.toggleTripReminders(v, tripProvider: tripProvider);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error, style: const TextStyle(color: Colors.white)),
                              backgroundColor: AppColors.cardBg(context),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.borderGlass(context)),
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 52),

                    _TappableRow(
                      icon: themeProvider.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      iconColor: AppColors.accentCyan,
                      title: 'Theme',
                      subtitle: themeProvider.isDarkMode ? 'Dark' : 'Light',
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            themeProvider.isDarkMode ? 'Dark' : 'Light',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.cyanAccent(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                      onTap: () => _showThemeDialog(context, themeProvider, auth),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionLabel(label: 'APP'),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _TappableRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.accentCyan,
                      title: 'Data Sources & About',
                      subtitle: 'Official travel data and app information',
                      onTap: () => _showDataSourcesSheet(context),
                    ),
                    const Divider(height: 1, indent: 52),
                    _TappableRow(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.safeGreen,
                      title: 'Privacy & Data',
                      subtitle: 'How your information is handled',
                      onTap: () => _showPrivacySheet(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _handleSignOut(context, auth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: AppColors.dangerRed, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.dangerRed,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: Column(
                  children: [
                    Text(
                      'HappyWay v1.2.0',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smart Malaysian Travel Assistant',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    AuthProvider auth,
    String initials,
    String? realName,
    String? realEmail,
  ) {
    return GlassCard(
      child: Row(
        children: [

          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.weatherBlue, AppColors.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        realName ?? '—',
                        style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () => _showEditProfileDialog(context, auth),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.edit_outlined,
                          color: AppColors.accentCyan,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                Text(
                  realEmail ?? '—',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.safeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Signed in',
                        style: AppTextStyles.badgeLabel.copyWith(
                          color: AppColors.safeGreen,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int savedCount, int tripCount) {
    return Row(
      children: [

        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Provider.of<NavigationProvider>(context, listen: false).setTab(2);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bookmark_outline_rounded,
                        color: AppColors.cyanAccent(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$savedCount ${savedCount == 1 ? 'destination' : 'destinations'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.secondaryText(context),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedText(context),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Provider.of<NavigationProvider>(context, listen: false).setTab(1);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.blueAccent(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.luggage_rounded,
                        color: AppColors.blueAccent(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trips',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$tripCount planned ${tripCount == 1 ? 'trip' : 'trips'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.secondaryText(context),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.mutedText(context),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppColors.surfaceGlass(context),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentCyan,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loading profile…',
                  style: TextStyle(color: AppColors.secondaryText(context), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGlass(context)),
            ),
            child: Icon(Icons.person_outline_rounded, color: AppColors.mutedText(context), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unable to load profile.', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 14)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => auth.restoreSession(),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.cyanAccent(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.cyanAccent(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.mutedText(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _TappableRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                    ),
                  ],
                ],
              ),
            ),
            trailingWidget ?? Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.blueAccent(context),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _DataSourcesSheet extends StatelessWidget {
  const _DataSourcesSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.40,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.borderGlass(ctx))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedText(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Data Sources & About', style: AppTextStyles.titleMedium.copyWith(fontSize: 18, color: AppColors.primaryText(ctx))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'HappyWay uses the following official and open-source data to power travel recommendations.',
                style: TextStyle(color: AppColors.secondaryText(ctx), fontSize: 13),
              ),
            ),
            Divider(color: AppColors.dividerColor(ctx)),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: const [
                  _AboutEntry(
                    icon: Icons.wb_cloudy_outlined,
                    iconColor: AppColors.weatherBlue,
                    category: 'Weather',
                    title: 'Official MET Malaysia Forecast',
                    description:
                        'Used for official destination weather forecast information across 448+ towns, districts, and tourist destinations in Malaysia.',
                  ),
                  SizedBox(height: 16),
                  _AboutEntry(
                    icon: Icons.route_rounded,
                    iconColor: AppColors.safeGreen,
                    category: 'Routes',
                    title: 'OSRM Route Engine',
                    description:
                        'Used for road distance calculation and estimated driving duration between origin and destination. Does not reflect live traffic conditions.',
                  ),
                  SizedBox(height: 16),
                  _AboutEntry(
                    icon: Icons.storage_rounded,
                    iconColor: AppColors.accentCyan,
                    category: 'Cloud Account & Storage',
                    title: 'Supabase',
                    description:
                        'Used for authentication, user profile storage, saved destinations, planned trips, and user preferences. All user data is isolated by account.',
                  ),
                  SizedBox(height: 16),
                  _AboutEntry(
                    icon: Icons.auto_graph_rounded,
                    iconColor: Color(0xFFAB8BFF),
                    category: 'Travel Recommendations',
                    title: 'HappyWay Rule-Based Engine',
                    description:
                        'Travel scores, destination match percentages, recommended travel periods, and trip explanations are generated by HappyWay\'s own rule-based logic. These are HappyWay-derived outputs and are not official MET Malaysia recommendations.',
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutEntry extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String category;
  final String title;
  final String description;

  const _AboutEntry({
    required this.icon,
    required this.iconColor,
    required this.category,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  color: AppColors.mutedText(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(color: AppColors.primaryText(context), fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyDataSheet extends StatelessWidget {
  const _PrivacyDataSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.40,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.borderGlass(ctx))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedText(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Privacy & Data', style: AppTextStyles.titleMedium.copyWith(fontSize: 18, color: AppColors.primaryText(ctx))),
            ),
            Divider(color: AppColors.dividerColor(ctx)),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: const [
                  _PrivacyItem(
                    icon: Icons.account_circle_outlined,
                    iconColor: AppColors.accentCyan,
                    title: 'Account Identity',
                    detail:
                        'Your account identity is managed through Supabase Auth. Your Supabase Auth UUID links your profile, saved destinations, planned trips, and user preferences.',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    icon: Icons.cloud_outlined,
                    iconColor: AppColors.weatherBlue,
                    title: 'Cloud Storage',
                    detail:
                        'Saved destinations and planned trips are stored in the cloud under your authenticated account only. They are not visible to other users.',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    icon: Icons.location_on_outlined,
                    iconColor: AppColors.safeGreen,
                    title: 'Location Usage',
                    detail:
                        'Your current GPS location is used primarily for travel routing (distance and estimated drive time to your chosen destination). It is not permanently stored in the database, unless you explicitly choose it as a planned trip origin.',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    icon: Icons.radar_rounded,
                    iconColor: AppColors.cautionAmber,
                    title: 'No Background Tracking',
                    detail:
                        'HappyWay does not perform background location tracking. Location is only accessed when you are actively using the app.',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    icon: Icons.password_rounded,
                    iconColor: Color(0xFFAB8BFF),
                    title: 'Passwords',
                    detail:
                        'Passwords are managed entirely by Supabase Auth and are never stored locally on your device by HappyWay.',
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;

  const _PrivacyItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: AppColors.primaryText(context), fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(detail,
                  style: TextStyle(
                      color: AppColors.secondaryText(context), fontSize: 13, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
