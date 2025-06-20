import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:http/http.dart' as http;
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:new_project_location/constants.dart';
import 'package:new_project_location/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FocusNode _codeFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _passwordCheckFocus = FocusNode();
  final FocusNode _regNoFocus = FocusNode();
  final FocusNode _firstnameFocus = FocusNode();
  final FocusNode _lastnameFocus = FocusNode();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    _regNoController.dispose();
    _firstnameFocus.dispose();
    _lastnameFocus.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _passwordCheckFocus.dispose();
    _scrollController.dispose();
    _passwordController.removeListener(_updatePasswordRules);
    _passwordCheckController.removeListener(_updatePasswordRules);
    super.dispose();
  }

  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, String>? _selectedRole;

  bool _isPasswordVisible = false;
  bool _isPasswordCheckVisible = false;
  int _selectedToggleIndex = 0; //0-Иргэн, 1-103
  double _dragPosition = 0.0;

  bool _isKeyboardVisible = false;

  List<Map<String, String>> _serverNames = [];
  Map<String, dynamic> sharedPreferencesData = {};

  Map<String, bool> _passwordRulesStatus = {};
  String? _passwordCheckValidationError;
  String? _regNoValidationError;
  String? _firstnameValidationError;
  String? _lastnameValidationError;

  // static const platform = MethodChannel(
  //   'com.example.new_project_location/location',
  // );

  final RegExp _regNoRegex = RegExp(
    r'^[А-ЯӨҮ]{2}[0-9]{2}(0[1-9]|1[0-2]|2[0-9]|3[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{2}$',
  );
  final RegExp mongolianCyrillicRegex = RegExp(r'^[А-Яа-яӨөҮүЁё]+$');

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;

    if (_isKeyboardVisible != newValue) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  bool isMongolianCyrillic(String text) {
    return mongolianCyrillicRegex.hasMatch(text);
  }

  Future<void> _getInitialScreenString() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? xServer = prefs.getString('X-Server');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Token');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      debugPrint(
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername',
      );
    } else {
      return debugPrint("empty shared");
    }
  }

  Future<void> _fetchServerData() async {
    const url = 'https://runner-api-v2.medsoft.care/api/gateway/servers';
    final headers = {'X-Token': Constants.xToken};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<Map<String, String>> serverNames =
              List<Map<String, String>>.from(
                data['data'].map<Map<String, String>>((server) {
                  return {
                    'name': server['name'].toString(),
                    'url': server['url'].toString(),
                  };
                }),
              );

          setState(() {
            _serverNames = serverNames;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load servers.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error fetching server data.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Exception: $e';
      });
    }
  }

  void _updatePasswordRules() {
    final password = _passwordController.text;
    final rules = _validatePasswordRules(password);

    setState(() {
      _passwordRulesStatus = rules;
      _passwordCheckValidationError = _validatePasswordMatch(
        password,
        _passwordCheckController.text,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _passwordController.addListener(_updatePasswordRules);
    _passwordCheckController.addListener(_updatePasswordRules);
    _regNoController.addListener(_validateRegNo);
    _firstnameController.addListener(_validateName);
    _lastnameController.addListener(_validateName);

    _dragPosition =
        _selectedToggleIndex *
        ((MediaQueryData.fromView(WidgetsBinding.instance.window).size.width -
                32 -
                8) /
            2);
    _fetchServerData();
    _getInitialScreenString();
  }

  void _validateRegNo() {
    final regNo = _regNoController.text.trim().toUpperCase();

    setState(() {
      if (regNo.isEmpty) {
        _regNoValidationError = null;
      } else if (!_regNoRegex.hasMatch(regNo)) {
        _regNoValidationError = 'Регистрын дугаар буруу байна';
      } else {
        _regNoValidationError = null;
      }
    });
  }

  void _validateName() {
    final firstname = _firstnameController.text.trim().toUpperCase();
    final lastname = _lastnameController.text.trim().toUpperCase();

    setState(() {
      if (firstname.isEmpty) {
        _firstnameValidationError = null;
      } else if (!mongolianCyrillicRegex.hasMatch(firstname)) {
        _firstnameValidationError = 'Кирилл үсгээр бичнэ үү.';
      } else {
        _firstnameValidationError = null;
      }

      if (lastname.isEmpty) {
        _lastnameValidationError = null;
      } else if (!mongolianCyrillicRegex.hasMatch(lastname)) {
        _lastnameValidationError = 'Кирилл үсгээр бичнэ үү.';
      } else {
        _lastnameValidationError = null;
      }
    });
  }

  bool _validateRegisterInputs() {
    final password = _passwordController.text;
    final passwordMatchError = _validatePasswordMatch(
      password,
      _passwordCheckController.text,
    );
    final rules = _validatePasswordRules(password);

    final regNo = _regNoController.text.trim().toUpperCase();
    if (regNo.isEmpty || !_regNoRegex.hasMatch(regNo)) {
      _regNoValidationError = 'Регистрын дугаар буруу байна';
    } else {
      _regNoValidationError = null;
    }

    setState(() {
      _passwordRulesStatus = rules;
      _passwordCheckValidationError = passwordMatchError;
    });

    final allPassed = rules.values.every((passed) => passed == true);
    return allPassed &&
        passwordMatchError == null &&
        _regNoValidationError == null;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    if (_selectedRole == null) {
      setState(() {
        _errorMessage = 'Эмнэлэг сонгоно уу.';
        _isLoading = false;
      });
      return;
    }

    final body = {
      'username': _usernameController.text,
      'password': _passwordController.text,
      'passwordCheck': _passwordController.text,
    };

    final headers = {
      'X-Token': Constants.xToken,
      'X-Server': _selectedRole?['name'] ?? '',
      'Content-Type': 'application/json',
    };

    debugPrint('Request Headers: $headers');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse('https://runner-api-v2.medsoft.care/api/gateway/auth'),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        FlutterAppBadger.removeBadge();
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          final String token = data['data']['token'];

          await prefs.setString('X-Server', _selectedRole?['name'] ?? '');
          await prefs.setString('X-Medsoft-Token', token);
          await prefs.setString('Username', _usernameController.text);

          await FlutterAppBadger.updateBadgeCount(0);

          _loadSharedPreferencesData();

          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            MaterialPageRoute(
              builder: (context) {
                return const MyHomePage(title: 'Байршил тогтоогч');
              },
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Нэвтрэх үйлдэл амжилтгүй: ${data['message']}';
            _isLoading = false;
          });
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _errorMessage = 'Нэвтрэх үйлдэл амжилтгүй. Ахин оролдоно уу.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Алдаа: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn') {
        data[key] = prefs.getBool(key);
      } else {
        data[key] = prefs.getString(key) ?? 'null';
      }
    }

    setState(() {
      sharedPreferencesData = data;
    });
  }

  Map<String, bool> _validatePasswordRules(String password) {
    return {
      'Нууц үгэнд дор хаяж нэг тоо байх ёстой': password.contains(
        RegExp(r'\d'),
      ),
      'Нууц үгэнд дор хаяж нэг жижиг үсэг байх ёстой': password.contains(
        RegExp(r'[a-z]'),
      ),
      'Нууц үгэнд дор хаяж нэг том үсэг байх ёстой': password.contains(
        RegExp(r'[A-Z]'),
      ),
      'Нууц үгэнд дор хаяж нэг тусгай тэмдэгт байх ёстой': password.contains(
        RegExp(r"[!@#&()\[\]{}:;',?/*~$^+=<>]"),
      ),
      'Нууц үгийн урт 10-35 тэмдэгт байх ёстой':
          password.length >= 10 && password.length <= 35,
    };
  }

  String? _validatePasswordMatch(String password, String confirmPassword) {
    if (password != confirmPassword) {
      return 'Нууц үг таарахгүй байна';
    }
    return null;
  }

  Widget buildAnimatedToggle() {
    List<Map<String, String>> toggleOptions = [
      {'label': 'Нэвтрэх'},
      {'label': 'Бүртгүүлэх'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        double totalWidth = constraints.maxWidth; // 16 padding on each side
        // if (totalWidth < 0) totalWidth = constraints.maxWidth; // safety check

        double knobWidth =
            (totalWidth - 8) / 2; // keep 8 as gap between toggles

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragPosition += details.delta.dx;
              _dragPosition = _dragPosition.clamp(0, knobWidth);
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              if (_dragPosition < (knobWidth / 2)) {
                _selectedToggleIndex = 0;
                _dragPosition = 0;
              } else {
                _selectedToggleIndex = 1;
                _dragPosition = knobWidth;
              }
            });
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx;
            setState(() {
              if (dx < totalWidth / 2) {
                _selectedToggleIndex = 0;
                _dragPosition = 0;
              } else {
                _selectedToggleIndex = 1;
                _dragPosition = knobWidth;
              }
            });
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  left: _dragPosition,
                  top: 0,
                  bottom: 0,
                  width: knobWidth,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color:
                          _selectedToggleIndex == 0
                              ? const Color(0xFF009688)
                              : const Color(0xFF0077b3),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),

                Row(
                  children: List.generate(toggleOptions.length, (index) {
                    final option = toggleOptions[index];
                    final isSelected = index == _selectedToggleIndex;

                    return Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              index == 0 ? Icons.login : Icons.person_add,
                              color: isSelected ? Colors.white : Colors.black87,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              option['label']!,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  KeyboardActionsConfig _buildKeyboardActionsConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      nextFocus: true,
      keyboardBarColor: Colors.grey[200],
      actions: [
        if (_selectedToggleIndex == 0)
          KeyboardActionsItem(focusNode: _codeFocus),
        if (_selectedToggleIndex == 1) ...[
          KeyboardActionsItem(
            focusNode: _usernameFocus,
            displayArrows: true,
            onTapAction: () => _scrollIntoView(_usernameFocus),
          ),
          KeyboardActionsItem(
            focusNode: _passwordFocus,
            displayArrows: true,
            onTapAction: () => _scrollIntoView(_passwordFocus),
          ),
          KeyboardActionsItem(
            focusNode: _passwordCheckFocus,
            displayArrows: true,
            onTapAction: () => _scrollIntoView(_passwordCheckFocus),
          ),
        ],
      ],
    );
  }

  void _scrollIntoView(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child:
              _selectedToggleIndex == 1
                  ? KeyboardActions(
                    config: _buildKeyboardActionsConfig(context),
                    child: _buildLoginForm(),
                  )
                  : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth;
        if (constraints.maxWidth >= 600) {
          // Tablet or wider screen: 30% width
          maxWidth = constraints.maxWidth * 0.5;
        } else {
          // Phone: full width (with padding)
          maxWidth = constraints.maxWidth - 32;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icon/locationlogoTrans.png',
                      height: 150,
                    ),
                    const Text(
                      'Тавтай морил',
                      style: TextStyle(
                        fontSize: 22.4,
                        color: Color(0xFF009688),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    buildAnimatedToggle(),
                    const SizedBox(height: 20),

                    // if (_selectedToggleIndex == 0)
                    //   TextFormField(
                    //     controller: _codeController,
                    //     focusNode: _codeFocus,
                    //     textInputAction: TextInputAction.done,
                    //     onFieldSubmitted:
                    //         (_) => FocusScope.of(context).unfocus(),
                    //     keyboardType: TextInputType.text,
                    //     decoration: InputDecoration(
                    //       labelText: 'Нэг удаагын код',
                    //       prefixIcon: const Icon(Icons.vpn_key),
                    //       border: OutlineInputBorder(
                    //         borderRadius: BorderRadius.circular(12),
                    //       ),
                    //     ),
                    //   ),
                    if (_serverNames.isNotEmpty &&
                        (_selectedToggleIndex == 0 ||
                            _selectedToggleIndex == 1))
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF808080),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_hospital,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButton<Map<String, String>>(
                                value: _selectedRole,
                                hint: const Text('Эмнэлэг сонгох'),
                                isExpanded: true,
                                onChanged: (
                                  Map<String, String>? newValue,
                                ) async {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedRole = newValue;
                                      _errorMessage = '';
                                    });
                                    SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'forgetUrl',
                                      newValue['url'] ?? '',
                                    );
                                  }
                                },
                                items:
                                    _serverNames.map<
                                      DropdownMenuItem<Map<String, String>>
                                    >((Map<String, String> value) {
                                      return DropdownMenuItem<
                                        Map<String, String>
                                      >(
                                        value: value,
                                        child: Text(value['name']!),
                                      );
                                    }).toList(),
                                underline: const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_serverNames.isNotEmpty &&
                        (_selectedToggleIndex == 0 ||
                            _selectedToggleIndex == 1))
                      const SizedBox(height: 20),

                    if (_selectedToggleIndex == 0 || _selectedToggleIndex == 1)
                      TextFormField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocus);
                        },
                        decoration: InputDecoration(
                          labelText: 'Нэвтрэх нэр',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    if (_serverNames.isNotEmpty &&
                        (_selectedToggleIndex == 0 ||
                            _selectedToggleIndex == 1))
                      const SizedBox(height: 20),

                    if (_selectedToggleIndex == 0 || _selectedToggleIndex == 1)
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _login();
                          FocusScope.of(context).unfocus();
                        },
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Нууц үг',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    if (_selectedToggleIndex == 1 &&
                        _passwordController.text.isNotEmpty &&
                        _passwordRulesStatus.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            _passwordRulesStatus.entries.map((entry) {
                              return Row(
                                children: [
                                  Icon(
                                    entry.value
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color:
                                        entry.value ? Colors.green : Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            entry.value
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),

                    if (_serverNames.isNotEmpty &&
                        (_selectedToggleIndex == 0 ||
                            _selectedToggleIndex == 1))
                      const SizedBox(height: 20),
                    if (_selectedToggleIndex == 1)
                      TextFormField(
                        controller: _passwordCheckController,
                        focusNode: _passwordCheckFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _login();
                          FocusScope.of(context).unfocus();
                        },
                        obscureText: !_isPasswordCheckVisible,
                        decoration: InputDecoration(
                          labelText: 'Нууц үг давтах',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordCheckVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordCheckVisible =
                                    !_isPasswordCheckVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _passwordCheckValidationError,
                        ),
                      ),

                    if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                    if (_selectedToggleIndex == 1)
                      TextFormField(
                        controller: _regNoController,
                        focusNode: _regNoFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocus);
                        },
                        decoration: InputDecoration(
                          labelText: 'Регистрын дугаар',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _regNoValidationError,
                        ),
                        onChanged: (value) {
                          _regNoController.value = _regNoController.value
                              .copyWith(
                                text: value.toUpperCase(),
                                selection: TextSelection.collapsed(
                                  offset: value.length,
                                ),
                              );
                        },
                      ),

                    if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                    if (_selectedToggleIndex == 1)
                      TextFormField(
                        controller: _lastnameController,
                        focusNode: _lastnameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocus);
                        },
                        decoration: InputDecoration(
                          labelText: 'Овог',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _lastnameValidationError,
                        ),
                        onChanged: (value) {
                          _lastnameController.value = _lastnameController.value
                              .copyWith(
                                text: value.toUpperCase(),
                                selection: TextSelection.collapsed(
                                  offset: value.length,
                                ),
                              );
                        },
                      ),

                    if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                    if (_selectedToggleIndex == 1)
                      TextFormField(
                        controller: _firstnameController,
                        focusNode: _firstnameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocus);
                        },
                        decoration: InputDecoration(
                          labelText: 'Нэр',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _firstnameValidationError,
                        ),
                        onChanged: (value) {
                          _firstnameController.value = _firstnameController
                              .value
                              .copyWith(
                                text: value.toUpperCase(),
                                selection: TextSelection.collapsed(
                                  offset: value.length,
                                ),
                              );
                        },
                      ),

                    if (_selectedToggleIndex == 1) const SizedBox(height: 20),

                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    if (_selectedToggleIndex == 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () async {
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            String? baseUrl = prefs.getString('forgetUrl');
                            String? hospital = _selectedRole?['name'];

                            if (baseUrl != null &&
                                baseUrl.isNotEmpty &&
                                hospital != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => WebViewScreen(
                                        url:
                                            '$baseUrl/forget?callback=medsofttrack://callback',
                                        title: hospital,
                                      ),
                                ),
                              );
                            } else {
                              setState(() {
                                _errorMessage =
                                    'Нууц үг солихын тулд эмнэлэг сонгоно уу.';
                              });
                            }
                          },
                          child: const Text(
                            'Нууц үг мартсан?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF009688),
                            ),
                          ),
                        ),
                      ),

                    if (_selectedToggleIndex == 0 || _selectedToggleIndex == 1)
                      const SizedBox(height: 10),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _selectedToggleIndex == 0
                                ? const Color(0xFF009688)
                                : const Color(0xFF0077b3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                if (_selectedToggleIndex == 1) {
                                  if (_validateRegisterInputs()) {
                                    _login();
                                  }
                                } else {
                                  _login();
                                }
                              },
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                _selectedToggleIndex == 0
                                    ? 'НЭВТРЭХ'
                                    : 'БҮРТГҮҮЛЭХ',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
