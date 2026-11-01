import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "M.irfan";
  String userEmail = "irfan@gmail.com";
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    Uint8List? imageBytes;
    final base64Image = prefs.getString('user_profile_image_base64');

    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        imageBytes = base64Decode(base64Image);
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
      }
    } else if (!kIsWeb) {
      final oldPath = prefs.getString('user_profile_image');
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          final file = File(oldPath);
          if (file.existsSync()) {
            imageBytes = await file.readAsBytes();
          }
        } catch (e) {
          debugPrint('Error loading image file: $e');
        }
      }
    }

    setState(() {
      userName = prefs.getString('user_name') ?? 'Guest User';
      userEmail = prefs.getString('user_email') ?? 'guest@email.com';
      _profileImageBytes = imageBytes;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        final Uint8List imageBytes = await pickedFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile_image_base64', base64String);

        if (mounted) {
          setState(() {
            _profileImageBytes = imageBytes;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile_image_base64');
    await prefs.remove('user_profile_image');
    if (mounted) {
      setState(() {
        _profileImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                child: Row(
                  children: [
                    const Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_profileImageBytes != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remove Photo',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _removeProfileImage();
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_profileImageBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeProfileImage();
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editNameDialog() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _SafeEditProfileNameDialog(
        initialName: userName,
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
      if (mounted) {
        setState(() {
          userName = newName;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.purple.withAlpha(30),
                      backgroundImage: _profileImageBytes != null
                          ? MemoryImage(_profileImageBytes!)
                          : null,
                      child: _profileImageBytes == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.purple,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Dynamic User Name & Email
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.teal),
                    onPressed: _editNameDialog,
                  ),
                ],
              ),
              Text(
                userEmail,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 30),

              // Profile Options Menu
              ProfileMenuWidget(
                title: 'Change Profile Photo',
                icon: Icons.photo_camera_outlined,
                onPress: _showImagePickerOptions,
              ),
              ProfileMenuWidget(
                title: 'Edit Profile Name',
                icon: Icons.edit_outlined,
                onPress: _editNameDialog,
              ),
              ProfileMenuWidget(
                title: 'Settings',
                icon: Icons.settings_outlined,
                onPress: () {},
              ),
              ProfileMenuWidget(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                onPress: () {},
              ),
              ProfileMenuWidget(
                title: 'Help & Support',
                icon: Icons.help_outline,
                onPress: () {},
              ),

              const Divider(height: 40, thickness: 1),

              // Logout Button
              ProfileMenuWidget(
                title: 'Log Out',
                icon: Icons.logout,
                textColor: Colors.red,
                endIcon: false,
                onPress: () async {
                  try {
                    if (!kIsWeb) {
                      await GoogleSignIn.instance.signOut();
                    }
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                  SharedPreferences prefs =
                  await SharedPreferences.getInstance();

                  await prefs.clear();

                  if (!context.mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                        (Route<dynamic> route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMenuWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPress;
  final Color? textColor;
  final bool endIcon;

  const ProfileMenuWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.onPress,
    this.textColor,
    this.endIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onPress,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: icon == Icons.logout
              ? Colors.red.withAlpha(25)
              : Colors.blue.withAlpha(25),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(
          icon,
          color: textColor ?? Colors.blue,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: endIcon
          ? const Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: Colors.grey,
      )
          : null,
    );
  }
}

class _SafeEditProfileNameDialog extends StatefulWidget {
  final String initialName;
  const _SafeEditProfileNameDialog({required this.initialName});

  @override
  State<_SafeEditProfileNameDialog> createState() => _SafeEditProfileNameDialogState();
}

class _SafeEditProfileNameDialogState extends State<_SafeEditProfileNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      FocusScope.of(context).unfocus();
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile Name'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}