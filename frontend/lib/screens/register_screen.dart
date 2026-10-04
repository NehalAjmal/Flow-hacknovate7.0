import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import 'app_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _accountType = 'solo'; 
  bool _isObscured = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyCodeController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedSex = 'Prefer not to say';

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyCodeController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final url = Uri.parse('http://127.0.0.1:8002/auth/register');
      
      final payload = {
        'full_name': _fullNameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'account_type': _accountType,
        'company_code': _accountType != 'solo' ? _companyCodeController.text : null,
        'age': int.tryParse(_ageController.text),
        'sex': _selectedSex,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        final String realToken = data['access_token'] ?? data['token']; 
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', realToken);
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppShell()),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['detail'] ?? "Invalid registration data. Please try again.");
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
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
                    Text("Create your account", style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text("Initialize your cognitive baseline baseline.", style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
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
                          Expanded(child: _buildTab("Company", 'company_employee', theme)),
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

                    _buildTextField("Full Name", Icons.person_outline, false, theme, _fullNameController),
                    const SizedBox(height: 20),
                    _buildTextField("Email address", Icons.email_outlined, false, theme, _emailController),
                    const SizedBox(height: 20),
                    
                    if (_accountType != 'solo') ...[
                      _buildTextField("Company Code", Icons.business_rounded, false, theme, _companyCodeController),
                      const SizedBox(height: 20),
                    ],
                    
                    Row(
                      children: [
                         Expanded(child: _buildTextField("Age", Icons.calendar_today_outlined, false, theme, _ageController, isNumeric: true)),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Sex", style: theme.textTheme.labelSmall),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: theme.scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedSex,
                                    dropdownColor: theme.cardColor,
                                    items: ['Prefer not to say', 'Male', 'Female', 'Other'].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value, style: theme.textTheme.bodyMedium),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedSex = v!),
                                  ),
                                ),
                              ),
                            ]
                           ),
                         )
                      ],
                    ),
                    const SizedBox(height: 20),
                    
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
                        onPressed: _isLoading ? null : _handleRegister,
                        child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Sign Up →", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                           Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: Text.rich(
                          TextSpan(
                            text: "Already have an account? ",
                            style: theme.textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: "Sign in",
                                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                              )
                            ]
                          )
                        )
                      )
                    )
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
    final isSelected = _accountType == value;
    return InkWell(
      onTap: () => setState(() { _accountType = value; _errorMessage = null; }),
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

  Widget _buildTextField(String label, IconData icon, bool isPassword, ThemeData theme, TextEditingController controller, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && _isObscured,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
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
