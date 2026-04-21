import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../nav.dart';
import '../providers/app_state.dart';
import '../components/account_tile.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AccountOverviewPage extends StatefulWidget {
  const AccountOverviewPage({super.key});

  @override
  State<AccountOverviewPage> createState() => _AccountOverviewPageState();
}

class _AccountOverviewPageState extends State<AccountOverviewPage> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }


  @override
  void initState() {
    super.initState();
    // In a real app, you'd pull the name from AppState or a UserProfile model
    _nameController = TextEditingController(text: 'Shree Pingale');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final isHi = appState.selectedLang == 'Hindi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isHi ? 'मेरा खाता' : 'My Account'),
        centerTitle: true,
        actions: [
          // Toggle Edit Mode or Save
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => setState(() => _isEditing = false),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: () => setState(() => _isEditing = true),
            ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(theme, isHi),
            const SizedBox(height: 32),

            // Section Label
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isHi ? 'विवरण' : 'DETAILS',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name Field (Conditional Widget)
            _isEditing
                ? TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: isHi ? 'नाम' : 'Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  )
                : AccountTile(
                    icon: Icons.person_outline,
                    title: isHi ? 'नाम' : 'Name',
                    subtitle: _nameController.text,
                  ),
            
            const SizedBox(height: 12),

            // Language (Non-editable here, routes to selection)
            AccountTile(
              icon: Icons.translate_rounded,
              title: isHi ? 'भाषा' : 'Language',
              subtitle: appState.selectedLang,
              onTap: () => context.push('/language-selection'),
            ),

            const SizedBox(height: 12),

            // Payment
            AccountTile(
              icon: Icons.account_balance_wallet_outlined,
              title: isHi ? 'भुगतान सेटअप' : 'Payment Setup',
              subtitle: isHi ? 'सक्रिय' : 'Active (UPI/Bank)',
              onTap: () => {}, // Future logic
            ),

            const SizedBox(height: 32),

            // Statistics Section with requested Routing
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStat(
                      context, 
                      '${appState.myProducts.length}', 
                      isHi ? 'सामान' : 'Products',
                      () => context.push(AppRoutes.editProducts), // Added Route
                    ),
                  ),
                  VerticalDivider(color: theme.colorScheme.tertiary.withOpacity(0.2)),
                  Expanded(
                    child: _buildStat(
                      context, 
                      '12', 
                      isHi ? 'आदेश' : 'Orders',
                      () => context.push(AppRoutes.myOrders), // Added Route
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, bool isHi) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickImage : null, // Only clickable in edit mode
          child: Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider
                    : const AssetImage('assets/images/Indian_artisan_working_brown_1769327616488.jpg'),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    radius: 18,
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_isEditing) ...[
          Text(_nameController.text, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(isHi ? 'कुशल कारीगर' : 'Master Artisan', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
        ] else
          Text(isHi ? 'तस्वीर बदलें' : 'Tap photo to change', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStat(BuildContext context, String value, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.tertiary)),
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Icon(Icons.arrow_right_alt, size: 16, color: theme.colorScheme.tertiary.withOpacity(0.5)),
        ],
      ),
    );
  }
}