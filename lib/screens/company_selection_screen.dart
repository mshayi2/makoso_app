import 'dart:ui';

import 'package:flutter/material.dart';

import 'makoso_dashboard_screen.dart';
import 'marina_dashboard_screen.dart';

enum AppCompany { makoso, marinaTrans }

class CompanySelectionScreen extends StatelessWidget {
  const CompanySelectionScreen({super.key});

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
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1A237E),
            ),
          ),

          // Blur overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.business_rounded,
                      size: 44, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Bienvenue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choisissez votre espace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 48),

                // Cards row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompanyCard(
                          title: 'MAKOSO\nService',
                          subtitle: 'Transit & Dédouanement',
                          icon: Icons.warehouse_rounded,
                          gradientColors: const [
                            Color(0xFF1E3A5F),
                            Color(0xFF2D6A9F),
                          ],
                          onTap: () => _navigate(context, AppCompany.makoso),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CompanyCard(
                          title: 'MARINA\nTrans',
                          subtitle: 'Transport & Logistique',
                          icon: Icons.local_shipping_rounded,
                          gradientColors: const [
                            Color(0xFF14532D),
                            Color(0xFF16A34A),
                          ],
                          onTap: () => _navigate(context, AppCompany.marinaTrans),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, AppCompany company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => company == AppCompany.marinaTrans
            ? const MarinaDashboardScreen()
            : const MakosoDashboardScreen(),
      ),
    );
  }
}

class _CompanyCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
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
          height: 220,
          width: double.infinity,
          transform: _hovered
              ? (Matrix4.identity()..scale(1.04))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.last.withValues(
                    alpha: _hovered ? 0.6 : 0.35),
                blurRadius: _hovered ? 28 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Accéder',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
