import 'package:flutter/material.dart';
import '../widgets/luxury_card.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final List<Map<String, String>> cards = [
    {
      "name": "Meyke",
      "role": "Flutter Developer",
      "image": "assets/images/m.jpg",
    },
    {
      "name": "Ahmed",
      "role": "UI Designer",
      "image": "assets/images/LL.jpg",
    },
    {
      "name": "Sarah",
      "role": "Backend Developer",
      "image": "assets/images/mm.jpg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),

      body: SafeArea(
        child: Column(
          children: [

            /// TITLE
            const SizedBox(height: 20),

            const Text(
              "LUX STACK",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 30),

            /// SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search cards...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// PAGE VIEW
            Expanded(
              child: PageView.builder(
                controller: PageController(
                  viewportFraction: 0.85,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {

                  final card = cards[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),

                    child: LuxuryCard(
                      name: card["name"]!,
                      role: card["role"]!,
                      image: card["image"]!,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}