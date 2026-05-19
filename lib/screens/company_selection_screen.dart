import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/utilisateur.dart';
import 'main_screen.dart';

class CompanySelectionScreen extends StatelessWidget {
  final Utilisateur user;
  final bool showDefaultPasswordWarning;

  const CompanySelectionScreen({
    super.key,
    required this.user,
    this.showDefaultPasswordWarning = false,
  });

  void _enter(BuildContext context, AppCompany company) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          user: user,
          company: company,
          showDefaultPasswordWarning: showDefaultPasswordWarning,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
          ),

          // Blur overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/images/container-truck.png',
                  height: 90,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'MAKOSO',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez un service',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 48),

                // Cards row
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // MAKOSO Services card
                        Expanded(
                          child: _CompanyCard(
                            title: 'MAKOSO',
                            subtitle: 'Services',
                            icon: Icons.folder_copy_outlined,
                            color: const Color(0xFF1A237E),
                            onTap: () => _enter(context, AppCompany.makoso),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // MARINA Trans card
                        Expanded(
                          child: _CompanyCard(
                            title: 'MARINA',
                            subtitle: 'Trans',
                            icon: Icons.local_shipping_outlined,
                            color: const Color(0xFF00695C),
                            onTap: () => _enter(context, AppCompany.marian),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -6.0 : 0.0),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _hovered ? 1.0 : 0.88),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _hovered ? 0.6 : 0.4),
                blurRadius: _hovered ? 24 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 56, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
