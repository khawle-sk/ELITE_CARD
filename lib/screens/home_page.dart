

import 'package:flutter/material.dart';
import '../widgets/luxury_card.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final List<Map<String, String>> cards = [
    {
      "name": "Meyke",
      "role": "Flutter Developer",
      "image": "assets/images/profile1.jpg",
    },
    {
      "name": "Ahmed",
      "role": "UI Designer",
      "image": "assets/images/profile2.jpg",
    },
    {
      "name": "Sarah",
      "role": "Backend Developer",
      "image": "assets/images/profile3.jpg",
    },
  ];
  late PageController _pageController;
  double currentPage = 0;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.75,
    );
    _pageController.addListener(() {
      setState(() {
        currentPage = _pageController.page!;
      });
    });
  }
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            /// TITLE
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
                controller: _pageController,
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  double scale = 1.0;
                  if (_pageController.position.haveDimensions) {
                    scale = (1 - ((currentPage - index).abs() * 0.1))
                        .clamp(0.85, 1.0);
                  }
                  final card = cards[index];
                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: LuxuryCard(
                        name: card["name"]!,
                        role: card["role"]!,
                        image: card["image"]!,
                      ),
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