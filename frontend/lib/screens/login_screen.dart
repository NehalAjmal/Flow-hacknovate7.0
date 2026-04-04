import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'app_shell.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _loginMode = 'solo'; // 'solo', 'company', 'admin'
  bool _isObscured = true;

  void _handleLogin() {
    // Navigates directly into the Master App Shell
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 420, // Strict maximum width for a premium desktop login
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── LOGO & GREETING ───
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "F",
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: theme.primaryColor,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Welcome back",
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Log in to sync your cognitive state.",
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ─── MODE TABS ───
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildTab("Solo", 'solo', theme)),
                          Expanded(child: _buildTab("Company", 'company', theme)),
                          Expanded(child: _buildTab("Admin", 'admin', theme)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── INPUT FIELDS ───
                    _buildTextField("Email address", Icons.email_outlined, false, theme),
                    const SizedBox(height: 20),
                    if (_loginMode != 'solo') ...[
                      _buildTextField("Company Code", Icons.business_rounded, false, theme),
                      const SizedBox(height: 20),
                    ],
                    _buildTextField("Password", Icons.lock_outline_rounded, true, theme),
                    const SizedBox(height: 32),

                    // ─── SUBMIT BUTTON ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _handleLogin,
                        child: const Text("Sign In →", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── FOOTER LINKS ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: theme.textTheme.bodyMedium),
                        InkWell(
                          onTap: () {},
                          child: Text(
                            "Create one",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String title, String value, ThemeData theme) {
    final isSelected = _loginMode == value;
    return InkWell(
      onTap: () => setState(() => _loginMode = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? theme.textTheme.headlineMedium?.color : theme.textTheme.labelSmall?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, bool isPassword, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          obscureText: isPassword && _isObscured,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.scaffoldBackgroundColor,
            prefixIcon: Icon(icon, color: theme.textTheme.labelSmall?.color, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(_isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    color: theme.textTheme.labelSmall?.color,
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}