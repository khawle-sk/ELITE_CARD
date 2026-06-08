
import 'package:flutter/material.dart';

class LuxuryCard extends StatelessWidget {
  final String name;
  final String role;
  final String image;

  const LuxuryCard({
    super.key,
    required this.name,
    required this.role,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 500,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF000000),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          /// IMAGE
          CircleAvatar(
            radius: 55,
            backgroundImage: AssetImage(image),
          ),

          const SizedBox(height: 30),

          /// NAME
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 12),

          /// ROLE
          Text(
            role,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 40),

          /// PREMIUM LINE
          Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Colors.amber,
                  Colors.orange,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
