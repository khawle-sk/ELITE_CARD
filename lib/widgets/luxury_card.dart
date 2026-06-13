import 'package:flutter/material.dart';

class LuxuryCard extends StatelessWidget {

  final String name;
  final String role;
  final String image;
  final bool isActive;

  const LuxuryCard({
    super.key,
    required this.name,
    required this.role,
    required this.image,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {

    return AnimatedContainer(

      duration: const Duration(
        milliseconds: 350,
      ),

      curve: Curves.easeInOut,

      margin: const EdgeInsets.symmetric(
        horizontal: 10,
      ),

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(32),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xFF111827),
            Color(0xFF030712),
          ],
        ),

        border: Border.all(

          color: isActive
              ? Colors.white.withOpacity(0.10)
              : Colors.white.withOpacity(0.03),

          width: 1,
        ),

        boxShadow: [

          BoxShadow(

            color: isActive
                ? Colors.orange.withOpacity(0.18)
                : Colors.black.withOpacity(0.35),

            blurRadius: isActive ? 35 : 18,

            spreadRadius: isActive ? 2 : 0,

            offset: const Offset(0, 15),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          /// PROFILE IMAGE
          AnimatedContainer(

            duration: const Duration(
              milliseconds: 350,
            ),

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              boxShadow: [

                BoxShadow(

                  color: isActive
                      ? Colors.orange.withOpacity(0.20)
                      : Colors.white.withOpacity(0.05),

                  blurRadius: isActive ? 28 : 12,
                ),
              ],
            ),

            child: CircleAvatar(
              radius: isActive ? 58 : 54,
              backgroundImage: AssetImage(image),
            ),
          ),

          const SizedBox(height: 35),

          /// NAME
          AnimatedDefaultTextStyle(

            duration: const Duration(
              milliseconds: 300,
            ),

            style: TextStyle(
              color: Colors.white,

              fontSize: isActive ? 30 : 27,

              fontWeight: FontWeight.bold,

              letterSpacing: 1,
            ),

            child: Text(name),
          ),

          const SizedBox(height: 10),

          /// ROLE
          Text(
            role,

            style: TextStyle(
              color: Colors.grey.shade400,

              fontSize: isActive ? 18 : 16,

              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 35),

          /// PREMIUM LINE
          AnimatedContainer(

            duration: const Duration(
              milliseconds: 350,
            ),

            width: isActive ? 125 : 100,

            height: 4,

            decoration: BoxDecoration(

              borderRadius:
                  BorderRadius.circular(20),

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