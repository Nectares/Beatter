import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'rhythm_generator_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  // Lista dei moduli futuri per la sezione "Prossimamente"
  final List<Map<String, String>> comingSoonFeatures = [
    {
      'title': 'Ear Training Assistant',
      'description': 'Allena il tuo orecchio a riconoscere accordi, intervalli e intonazione in modo interattivo.',
      'icon': '👂',
    },
    {
      'title': 'Chord Progression Architect',
      'description': 'Crea progressioni armoniche complesse ed esportale in formato MIDI per le tue produzioni.',
      'icon': '🎹',
    },
    {
      'title': 'Scale & Arpeggio Explorer',
      'description': 'Esplora scale esotiche, modi gregoriani e arpeggi con grafici interattivi su tastiera e manico.',
      'icon': '🎸',
    },
    {
      'title': 'Interactive Drum Sequencer',
      'description': 'Un sequencer a griglia avanzato multitraccia per creare beat personalizzati con campioni di batteria storici.',
      'icon': '🥁',
    },
  ];

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.backgroundGradient,
        child: Stack(
          children: [
            // Sfondi sfumati decorativi (Glowing Orbs) per un look futuristico e premium
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryCyan.withOpacity(0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryPurple.withOpacity(0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar superiore personalizzata
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.secondaryCyan,
                              child: Icon(Icons.person, color: Colors.white, size: 20),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Benvenuto,',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Utente Standard',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Bottone di Logout
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          tooltip: 'Logout',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),

                  // Contenuto principale scorrevole
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          // Titolo Sezione
                          const Text(
                            'Funzionalità Attive',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 1. CARD PRINCIPALE: Random Rhythm Generator (UNICA FUNZIONALITÀ ATTIVA)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RhythmGeneratorPage()),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primaryPurple, AppTheme.secondaryCyan],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryCyan.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icona animata/decorativa a sfera neon
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Random Rhythm Generator',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Genera letture ritmiche professionali sul pentagramma. Allena il tuo timing con il player audio integrato.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Intestazione sezione "Prossimamente"
                          const Text(
                            'Prossimamente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Liste delle card placeholder disabilitate con blur ed opacità ridotta
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comingSoonFeatures.length,
                            itemBuilder: (context, index) {
                              final feature = comingSoonFeatures[index];
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    children: [
                                      // Card standard con opacità ridotta
                                      Opacity(
                                        opacity: 0.45,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                          decoration: AppTheme.glassCardDecoration(borderRadius: 16),
                                          child: Row(
                                            children: [
                                              // Icona stilizzata
                                              Container(
                                                width: 44,
                                                height: 44,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.08),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  feature['icon']!,
                                                  style: const TextStyle(fontSize: 22),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      feature['title']!,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      feature['description']!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme.textSecondary,
                                                        height: 1.25,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Filtro Blur e Badge sopra la card per inibire qualsiasi interazione
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                                            child: Container(
                                              color: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Badge "Coming Soon" in alto a destra
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                                          ),
                                          child: const Text(
                                            'Coming Soon',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
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
}
