import 'package:flutter/material.dart';
import '../widgets/luxury_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final List<Map<String, String>> allCards = [

    {
      "name": "Meyke",
      "role": "Flutter Developer",
      "image": "assets/images/mm.jpg",
    },

    {
      "name": "Ahmed",
      "role": "UI Designer",
      "image": "assets/images/LL.jpg",
    },

    {
      "name": "Sarah",
      "role": "Backend Developer",
      "image": "assets/images/hj.jpg",
    },

    {
      "name": "Amine",
      "role": "Mobile Engineer",
      "image": "assets/images/mm.jpg",
    },
  ];

  late List<Map<String, String>> filteredCards;

  late PageController _pageController;

  double currentPage = 0;

  @override
  void initState() {
    super.initState();

    filteredCards = allCards;

    _pageController = PageController(
      viewportFraction: 0.82,
    );

    _pageController.addListener(() {

      setState(() {
        currentPage = _pageController.page ?? 0;
      });

    });
  }

  void filterCards(String query) {

    final results = allCards.where((card) {

      final name = card["name"]!.toLowerCase();

      return name.startsWith(query.toLowerCase());

    }).toList();

    setState(() {
      filteredCards = results;
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

      body: Stack(

        children: [

          /// BACKGROUND
          Container(

            decoration: const BoxDecoration(

              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

                colors: [
                  Color(0xFF030712),
                  Color(0xFF111827),
                ],
              ),
            ),
          ),

          /// TOP RIGHT GLOW
          Positioned(
            top: -120,
            right: -80,

            child: Container(

              width: 260,
              height: 260,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: Colors.orange.withOpacity(0.08),
              ),
            ),
          ),

          /// BOTTOM LEFT GLOW
          Positioned(
            bottom: -140,
            left: -100,

            child: Container(

              width: 300,
              height: 300,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: Colors.blue.withOpacity(0.05),
              ),
            ),
          ),

          /// MAIN CONTENT
          SafeArea(

            child: Column(

              children: [

                const SizedBox(height: 20),

                /// TITLE
                const Text(
                  "LUX STACK",

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 25),

                /// SEARCH BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),

                  child: TextField(

                    onChanged: filterCards,

                    style: const TextStyle(
                      color: Colors.white,
                    ),

                    decoration: InputDecoration(

                      hintText: "Search cards...",

                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                      ),

                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),

                      filled: true,

                      fillColor:
                          Colors.white.withOpacity(0.06),

                      border: OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(20),

                        borderSide: BorderSide.none,
                      ),

                      focusedBorder: OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(20),

                        borderSide: BorderSide(
                          color:
                              Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                /// CARDS
                Expanded(

                  child: AnimatedSwitcher(

                    duration: const Duration(
                      milliseconds: 500,
                    ),

                    switchInCurve: Curves.easeOut,

                    switchOutCurve: Curves.easeIn,

                    child: PageView.builder(

                      key: ValueKey(
                        filteredCards.length,
                      ),

                      physics:
                          const BouncingScrollPhysics(),

                      controller: _pageController,

                      itemCount: filteredCards.length,

                      itemBuilder: (context, index) {

                        double distance =
                            (currentPage - index).abs();

                        double scale =
                            (1 - (distance * 0.08))
                                .clamp(0.90, 1.0);

                        double opacity =
                            (1 - (distance * 0.3))
                                .clamp(0.5, 1.0);

                        final card = filteredCards[index];

                        return Transform.translate(

                          offset: Offset(
                            0,
                            distance < 0.3 ? -12 : 0,
                          ),

                          child: Transform.scale(

                            scale: scale,

                            child: Opacity(

                              opacity: opacity,

                              child: Padding(

                                padding:
                                    const EdgeInsets.only(
                                  top: 40,
                                  bottom: 50,
                                ),

                                child: LuxuryCard(
                                  name: card["name"]!,
                                  role: card["role"]!,
                                  image: card["image"]!,
                                  isActive:
                                      distance < 0.3,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                /// PAGE INDICATOR
                Row(

                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: List.generate(

                    filteredCards.length,

                    (index) {

                      bool isActive =
                          currentPage.round() == index;

                      return AnimatedContainer(

                        duration: const Duration(
                          milliseconds: 300,
                        ),

                        margin:
                            const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),

                        width: isActive ? 26 : 8,

                        height: 8,

                        decoration: BoxDecoration(

                          borderRadius:
                              BorderRadius.circular(20),

                          color: isActive
                              ? Colors.orange
                              : Colors.white
                                  .withOpacity(0.2),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ],
      ),
    );
  }
}