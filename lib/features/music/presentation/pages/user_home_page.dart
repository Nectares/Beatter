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
  // Mock Data
  final List<Map<String, String>> albums = [
    {
      'title': 'Neon Horizon',
      'artist': 'Hyperwave',
      'tracks': '12 tracks',
      'color': '0xFF8B5CF6'
    },
    {
      'title': 'Midnight Chill',
      'artist': 'Lofi Beats',
      'tracks': '8 tracks',
      'color': '0xFF06B6D4'
    },
    {
      'title': 'Solar Wind',
      'artist': 'Stellar',
      'tracks': '10 tracks',
      'color': '0xFFEC4899'
    },
  ];

  final List<Map<String, String>> tracks = [
    {'title': 'Cyber Romance', 'artist': 'Hyperwave', 'duration': '3:45'},
    {'title': 'Starlight Drift', 'artist': 'Lofi Beats', 'duration': '4:12'},
    {'title': 'Nebula Voyage', 'artist': 'Stellar', 'duration': '5:01'},
    {'title': 'Glitch in Paradise', 'artist': 'RetroTech', 'duration': '2:58'},
    {'title': 'Synthetic Memories', 'artist': 'Vaporwave', 'duration': '3:34'},
  ];

  String _currentPlayingTitle = 'Seleziona un brano';
  String _currentPlayingArtist = 'Nessuna riproduzione';
  bool _isPlaying = false;

  void _playTrack(String title, String artist) {
    setState(() {
      _currentPlayingTitle = title;
      _currentPlayingArtist = artist;
      _isPlaying = true;
    });
  }

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
            // Safe Area content
            SafeArea(
              child: Column(
                children: [
                  // App bar / Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.secondaryCyan,
                              child: Icon(Icons.person, color: Colors.white),
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
                                  'Ascoltatore',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Log out
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          tooltip: 'Logout',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Area
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Box
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            key: const ValueKey('search_box'),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Cerca brani, album, artisti...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                                fillColor: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Rhythm Generator Promo Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RhythmGeneratorPage()),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryPurple, AppTheme.secondaryCyan],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.secondaryCyan.withOpacity(0.2),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    )
                                  ]
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Generatore Ritmico',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Crea sequenze automatiche e sperimenta con note e frequenze.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Albums Section
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Consigliati per te',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 170,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: albums.length,
                              itemBuilder: (context, index) {
                                final album = albums[index];
                                final colorVal = int.parse(album['color']!);
                                return Container(
                                  width: 150,
                                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                  padding: const EdgeInsets.all(14.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(colorVal).withOpacity(0.35),
                                        Color(colorVal).withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(colorVal).withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                      ),
                                      const Spacer(),
                                      Text(
                                        album['title']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        album['artist']!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Popular Songs List
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Brani Popolari',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: tracks.length,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              final isCurrent = _currentPlayingTitle == track['title'];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCurrent 
                                      ? AppTheme.secondaryCyan.withOpacity(0.1) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () => _playTrack(track['title']!, track['artist']!),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isCurrent && _isPlaying 
                                          ? Icons.volume_up_rounded 
                                          : Icons.music_note_rounded,
                                      color: isCurrent ? AppTheme.secondaryCyan : AppTheme.primaryPurple,
                                    ),
                                  ),
                                  title: Text(
                                    track['title']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? AppTheme.secondaryCyan : AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    track['artist']!,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  trailing: Text(
                                    track['duration']!,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 100), // Spacing for player
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mini Music Player
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.secondaryCyan.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondaryCyan.withOpacity(0.15),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ]
                    ),
                    child: Row(
                      children: [
                        // Song image
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryPurple, AppTheme.accentPink],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_video_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        // Track title/artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPlayingTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentPlayingArtist,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                            color: AppTheme.secondaryCyan,
                            size: 38,
                          ),
                          onPressed: () {
                            if (_currentPlayingTitle != 'Seleziona un brano') {
                              setState(() {
                                _isPlaying = !_isPlaying;
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
