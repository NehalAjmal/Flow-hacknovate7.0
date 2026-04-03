import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyCodeController = TextEditingController();
  
  double _age = 25; 
  String _sex = "male"; 
  bool _isCompanyEmployee = false;
  bool _isGoogleRegPending = false; 

  final Color flowGreen = const Color(0xFF1D9E75);

  void _handleRegister() {
    final Map<String, dynamic> payload = {
      "password": _passwordController.text,
      "age": _age.toInt(),
      "sex": _sex,
      "account_type": _isCompanyEmployee ? "company_employee" : "solo",
    };

    if (_isGoogleRegPending) {
      payload["auth_method"] = "google";
      payload["google_token"] = "simulated_oauth_token_123";
    } else {
      payload["auth_method"] = "standard";
      payload["full_name"] = _nameController.text;
      payload["email"] = _emailController.text;
    }

    if (_isCompanyEmployee) {
      payload["company_code"] = _companyCodeController.text;
    }

    print("Register Payload: $payload");
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: const [
          Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("OR", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white24)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Initialize Model", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  _isGoogleRegPending 
                    ? "Google profile linked. Please complete your system baselines." 
                    : "FLOW needs baseline biological data to protect your focus.",
                  style: TextStyle(color: _isGoogleRegPending ? flowGreen : Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Manual Entry or Pending Google Fields
                if (!_isGoogleRegPending) ...[
                  TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration("Full Name")),
                  const SizedBox(height: 16),
                  TextField(controller: _emailController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration("Email")),
                  const SizedBox(height: 16),
                ],
                
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(_isGoogleRegPending ? "Set Backup Password" : "Password (min 8 characters)"),
                ),
                const SizedBox(height: 24),

                // Biological Baselines (Always required)
                const Text("Biological Baselines", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Age:", style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: _age, min: 16, max: 80, divisions: 64, activeColor: flowGreen,
                        label: _age.round().toString(),
                        onChanged: (val) => setState(() => _age = val),
                      ),
                    ),
                    Text("${_age.round()}", style: TextStyle(color: flowGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sex,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration("Biological Sex (HRV Baseline)"),
                  items: const [
                    DropdownMenuItem(value: "male", child: Text("Male")),
                    DropdownMenuItem(value: "female", child: Text("Female")),
                    DropdownMenuItem(value: "prefer_not_to_say", child: Text("Prefer not to say")),
                  ],
                  onChanged: (val) => setState(() => _sex = val!),
                ),
                const SizedBox(height: 24),

                // Company Routing
                SwitchListTile(
                  title: const Text("I am joining a Company Team", style: TextStyle(color: Colors.white)),
                  activeColor: flowGreen,
                  contentPadding: EdgeInsets.zero,
                  value: _isCompanyEmployee,
                  onChanged: (val) => setState(() => _isCompanyEmployee = val),
                ),
                if (_isCompanyEmployee) ...[
                  const SizedBox(height: 8),
                  TextField(controller: _companyCodeController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration("Company Code")),
                ],
                
                const SizedBox(height: 32),
                
                // Primary Action Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: flowGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _handleRegister,
                  child: Text(_isGoogleRegPending ? "Finalize Account" : "Initialize Account", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                
                // Google Section / Cancellation
                if (_isGoogleRegPending) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _isGoogleRegPending = false),
                    child: const Text("Cancel Google Linking", style: TextStyle(color: Colors.white54)),
                  )
                ] else ...[
                  _buildDivider(),
                  OutlinedButton.icon(
                    // Using the Original Google Logo asset
                    icon: Image.asset('assets/google_logo.png', height: 24, width: 24),
                    label: const Text("Continue with Google", style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14), 
                      side: const BorderSide(color: Colors.white24),
                      backgroundColor: const Color(0xFF2A2A2A),
                    ),
                    onPressed: () => setState(() => _isGoogleRegPending = true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75))),
    );
  }
}