import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../utils/validators.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitted = false;
  bool _success = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.updatePassword(_newPasswordController.text);

    if (!mounted) return;

    if (success) {
      setState(() => _success = true);
    } else {
      final error = auth.errorMessage ?? 'Failed to update password. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(error, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryText(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Change Password', style: AppTextStyles.titleMedium.copyWith(fontSize: 18, color: AppColors.primaryText(context))),
      ),
      body: Stack(
        children: [

          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blueAccent(context).withValues(alpha: 0.10),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _success ? _buildSuccessView() : _buildForm(auth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.safeGreen.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.safeGreen, size: 42),
        ),
        const SizedBox(height: 24),
        Text('Password Updated', style: AppTextStyles.titleHero.copyWith(fontSize: 24, color: AppColors.primaryText(context))),
        const SizedBox(height: 8),
        Text(
          'Your password has been changed successfully.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.weatherBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: AppColors.cyanAccent(context), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Enter a new password for your HappyWay account. It will take effect immediately.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'New Password',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context), fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _inputDecoration(
              hint: 'Enter new password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.mutedText(context),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: 20),

          Text(
            'Confirm New Password',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context), fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(color: AppColors.primaryText(context)),
            decoration: _inputDecoration(
              hint: 'Confirm new password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.mutedText(context),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password.';
              if (value != _newPasswordController.text) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: auth.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                : ElevatedButton(
                    onPressed: _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.weatherBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Update Password',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.mutedText(context)),
      filled: true,
      fillColor: AppColors.inputFill(context),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.inputBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cyanAccent(context), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
      ),
    );
  }
}
