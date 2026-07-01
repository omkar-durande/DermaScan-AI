import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/connectivity_service.dart';

/// Animated offline/online banner that shows at the top of screens
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();
  late AnimationController _animController;
  late Animation<double> _heightAnim;

  bool _showOnlineFlash = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _heightAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);

    _connectivity.addListener(_onConnectivityChange);
    if (!_connectivity.isOnline) _animController.value = 1.0;
  }

  void _onConnectivityChange() {
    if (!mounted) return;
    if (!_connectivity.isOnline) {
      _wasOffline = true;
      _animController.forward();
    } else {
      _animController.reverse();
      if (_wasOffline) {
        setState(() => _showOnlineFlash = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showOnlineFlash = false);
        });
        _wasOffline = false;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChange);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        if (_animController.value == 0 && !_showOnlineFlash) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Offline banner
            SizeTransition(
              sizeFactor: _heightAnim,
              child: _buildOfflineBanner(),
            ),
            // "Back online" flash
            if (_showOnlineFlash) _buildOnlineFlash(),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.danger,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No internet connection',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => ConnectivityService().checkNow(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineFlash() {
    return AnimatedOpacity(
      opacity: _showOnlineFlash ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.success,
        child: const Row(
          children: [
            Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Back online ✓',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen offline overlay for critical operations (like scanning)
class OfflineOverlay extends StatelessWidget {
  final VoidCallback? onRetry;
  const OfflineOverlay({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.danger),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'DermaScan AI needs an internet connection to analyze skin lesions. Please check your Wi-Fi or mobile data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          if (onRetry != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
