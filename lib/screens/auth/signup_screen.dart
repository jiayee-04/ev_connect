import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorText;

  static final _emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
  static final _phoneRegex = RegExp(r'^0\d{1,2}-?\d{7,8}$');
  static final _hasLetter = RegExp(r'[A-Za-z]');
  static final _hasNumber = RegExp(r'[0-9]');
  static final _hasSymbol = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`;]');

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Minimum 6 characters';
    if (!_hasLetter.hasMatch(v)) return 'Include at least one letter';
    if (!_hasNumber.hasMatch(v)) return 'Include at least one number';
    if (!_hasSymbol.hasMatch(v)) return 'Include at least one symbol (e.g. ! @ # \$)';
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await AuthService.instance.register(
      AppUser(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      ),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _errorText = null;
      _loading = true;
    });
    final error = await AuthService.instance.loginWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Sign up to get started',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!_emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    hintText: '011-25978281',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (!_phoneRegex.hasMatch(v.trim())) {
                        return 'Enter a valid Malaysian phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: _obscure,
                    helperText:
                        'Min 6 characters, with a mix of letters, numbers and a symbol',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Confirm Password',
                    controller: _confirmController,
                    obscureText: _obscure,
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorText!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 18),
                  SocialSignInButtons(
                    loading: _loading,
                    onGoogleTap: _submitGoogle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
