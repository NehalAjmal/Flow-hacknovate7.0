import 'package:flutter/material.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showAdminFields = false;
  bool _isGoogleAuthPending = false; 

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _adminKeyController = TextEditingController();

  final Color flowGreen = const Color(0xFF1D9E75);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _showAdminFields = false;
        _isGoogleAuthPending = false; 
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyCodeController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  void _handleStandardLogin() {
    final String loginType = _tabController.index == 0 
        ? "solo" 
        : (_showAdminFields ? "admin" : "employee");

    final Map<String, dynamic> payload = {
      "email": _emailController.text,
      "password": _passwordController.text,
      "login_type": loginType,
      "auth_method": "standard",
    };

    if (_tabController.index == 1) {
      payload["company_code"] = _companyCodeController.text;
      if (_showAdminFields) payload["admin_key"] = _adminKeyController.text;
    }
    print("Standard Login Payload: $payload");
  }

  void _handleGoogleCompletion() {
    final String loginType = _tabController.index == 0 ? "solo" : "employee";
    
    final Map<String, dynamic> payload = {
      "password_setup": _passwordController.text, 
      "login_type": loginType,
      "auth_method": "google",
      "google_token": "simulated_oauth_token_123", 
    };

    if (_tabController.index == 1) {
      payload["company_code"] = _companyCodeController.text;
    }
    print("Google Login Payload: $payload");
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
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("FLOW", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text("Cognitive Alignment System", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 32),
                
                TabBar(
                  controller: _tabController,
                  indicatorColor: flowGreen,
                  labelColor: flowGreen,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [Tab(text: "Solo Login"), Tab(text: "Company Login")],
                ),
                const SizedBox(height: 24),
          
                // PENDING GOOGLE STATE
                if (_isGoogleAuthPending) ...[
                  const Text("Complete Google Sign-In", style: TextStyle(color: Color(0xFF1D9E75), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text("Please set a password for future native access.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Set Backup Password", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75)))),
                  ),
          
                  if (_tabController.index == 1) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _companyCodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Company Code", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75)))),
                    ),
                  ],
          
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: flowGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _handleGoogleCompletion,
                    child: const Text("Finalize Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isGoogleAuthPending = false),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                  )
                ] 
                else ...[
                  // STANDARD MANUAL LOGIN
                  if (!_showAdminFields)
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75)))),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75)))),
                  ),
                  
                  if (_tabController.index == 1) ...[
                    if (!_showAdminFields) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _companyCodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Company Code", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D9E75)))),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _showAdminFields = !_showAdminFields),
                        child: Text(_showAdminFields ? "Cancel Admin Login" : "Admin Login", style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                      ),
                    ),
                    if (_showAdminFields) 
                      TextField(
                        controller: _adminKeyController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "6-Digit Admin Key", labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent))),
                      ),
                  ],
          
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: flowGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _handleStandardLogin,
                    child: const Text("Enter FLOW", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  // GOOGLE BUTTON MOVED BELOW MANUAL LOGIN
                  if (!_showAdminFields) ...[
                    _buildDivider(),
                    OutlinedButton.icon(
                      // Using the Original Google Logo asset
                      icon: Image.asset('assets/google_logo.png', height: 24, width: 24),
                      label: const Text("Continue with Google", style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14), 
                        side: const BorderSide(color: Colors.white24),
                        backgroundColor: const Color(0xFF2A2A2A), // Slight dark contrast
                      ),
                      onPressed: () => setState(() => _isGoogleAuthPending = true),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: const Text("Create an account", style: TextStyle(color: Colors.white54)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}