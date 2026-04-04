import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import 'app_shell.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _loginMode = 'solo'; 
  bool _isObscured = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyCodeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final url = Uri.parse('http://127.0.0.1:8000/auth/login');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
          'mode': _loginMode,
          'company_code': _loginMode != 'solo' ? _companyCodeController.text : null,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // SAVE TOKEN FOR DASHBOARDS TO USE
        final String realToken = data['access_token'] ?? data['token'] ?? 'fake-jwt-token-12345'; 
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', realToken);
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppShell()),
        );
      } else {
        setState(() => _errorMessage = "Invalid credentials. Please try again.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Cannot connect to server.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            width: 420, 
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text("F", style: theme.textTheme.displayLarge?.copyWith(color: theme.primaryColor, fontSize: 32)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("Welcome back", style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text("Log in to sync your cognitive state.", style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 32),

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

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                    ],

                    _buildTextField("Email address", Icons.email_outlined, false, theme, _emailController),
                    const SizedBox(height: 20),
                    if (_loginMode != 'solo') ...[
                      _buildTextField("Company Code", Icons.business_rounded, false, theme, _companyCodeController),
                      const SizedBox(height: 20),
                    ],
                    _buildTextField("Password", Icons.lock_outline_rounded, true, theme, _passwordController),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Sign In →", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
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
      onTap: () => setState(() { _loginMode = value; _errorMessage = null; }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        alignment: Alignment.center,
        child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: isSelected ? theme.textTheme.headlineMedium?.color : theme.textTheme.labelSmall?.color, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, bool isPassword, ThemeData theme, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && _isObscured,
          decoration: InputDecoration(
            filled: true, fillColor: theme.scaffoldBackgroundColor,
            prefixIcon: Icon(icon, color: theme.textTheme.labelSmall?.color, size: 20),
            suffixIcon: isPassword ? IconButton(icon: Icon(_isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), color: theme.textTheme.labelSmall?.color, onPressed: () => setState(() => _isObscured = !_isObscured)) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor, width: 1.5)),
          ),
        ),
      ],
    );
  }
}