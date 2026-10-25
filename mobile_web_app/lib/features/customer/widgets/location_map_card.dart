import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/animated_glass_card.dart';

class LocationMapCard extends StatefulWidget {
  const LocationMapCard({super.key});

  @override
  State<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends State<LocationMapCard> {
  // Cafeana Shop Location: 57JM+CG Bay, Laguna (approx 14.1797°N, 121.2719°E)
  final double _shopLat = 14.1797;
  final double _shopLng = 121.2719;
  final String _shopAddress = '57JM+CG Bay, Laguna';
  bool _isLoading = false;

  Future<void> _getDirections() async {
    setState(() => _isLoading = true);
    
    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _launchMapsDirectly();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _launchMapsDirectly();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _launchMapsDirectly();
        return;
      }

      // Try to get current location to give exact routing
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      
      final url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}&destination=$_shopLat,$_shopLng');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _launchMapsDirectly();
      }
    } catch (e) {
      // Fallback to destination only if location fails
      _launchMapsDirectly();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _launchMapsDirectly() async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_shopLat,$_shopLng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulated Map Graphic
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A231F) : const Color(0xFFE8D5C4),
              gradient: LinearGradient(
                colors: [
                  isDark ? const Color(0xFF2C2420) : const Color(0xFFE8D5C4),
                  isDark ? const Color(0xFF1F1814) : const Color(0xFFDCA87C).withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Faint grid pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: isDark ? 0.05 : 0.1,
                    child: GridPaper(
                      color: cs.onSurface,
                      divisions: 1,
                      subdivisions: 1,
                      interval: 20,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.store_mall_directory_rounded,
                      color: cs.onPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Details & Action
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cafeana',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: cs.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _shopAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _getDirections,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading 
                      ? SizedBox(
                          width: 18, 
                          height: 18, 
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          )
                        )
                      : const Icon(Icons.directions_outlined, size: 20),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
