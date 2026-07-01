import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scan_provider.dart';

/// Scan screen with in-app camera preview, gallery upload, and capture
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String? _cameraErrorMessage;

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle camera lifecycle when app is paused/resumed
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'No cameras available on this device';
        });
        return;
      }

      // Use back camera by default
      _selectedCameraIndex = 0;
      for (int i = 0; i < _cameras!.length; i++) {
        if (_cameras![i].lensDirection == CameraLensDirection.back) {
          _selectedCameraIndex = i;
          break;
        }
      }

      await _setupCameraController(_cameras![_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _isCameraError = true;
        _cameraErrorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    // Dispose previous controller if any
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraError = false;
          _cameraErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Camera error: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isCameraInitialized = false);

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _setupCameraController(_cameras![_selectedCameraIndex]);
  }

  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _cameraController!.takePicture();
      setState(() {
        _selectedImage = File(image.path);
        _isCapturing = false;
      });
      _analyzeImage();
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
      _analyzeImage();
    }
  }

  void _analyzeImage() async {
    if (_selectedImage == null) return;
    final uid = context.read<AuthProvider>().uid ?? '';
    final result = await context.read<ScanProvider>().predictImage(_selectedImage!, uid);
    if (result != null && mounted) {
      // Save to history in background — don't block navigation
      context.read<HistoryProvider>().saveScan(result);
      Navigator.pushNamed(context, '/results', arguments: result);
    }
  }

  void _retakePhoto() {
    setState(() => _selectedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ScanProvider>(
        builder: (context, scan, _) {
          if (scan.isLoading) return _buildLoadingView();
          if (_selectedImage != null) return _buildPreviewView();
          return _buildCameraView();
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.splashGradient),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            SizedBox(height: 24),
            Text(AppStrings.analyzing, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('This may take a few seconds...', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewView() {
    final scanProvider = context.read<ScanProvider>();
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: _retakePhoto,
                ),
                const Spacer(),
                const Text('Review Photo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // Image preview
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, fit: BoxFit.contain, width: double.infinity),
              ),
            ),
          ),
          // Error message
          if (scanProvider.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(scanProvider.error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  ],
                ),
              ),
            ),
          // Bottom controls for preview
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Retake button
                GestureDetector(
                  onTap: _retakePhoto,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                  ),
                ),
                // Analyze button
                GestureDetector(
                  onTap: _analyzeImage,
                  child: Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(Icons.search_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                const Text('Skin Scanner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // Camera preview area
          Expanded(
            child: Center(
              child: _isCameraError
                  ? _buildCameraErrorView()
                  : _isCameraInitialized
                      ? _buildLiveCameraPreview()
                      : _buildCameraLoadingView(),
            ),
          ),
          // Bottom controls
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
                  ),
                ),
                // Capture button
                GestureDetector(
                  onTap: _captureImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: _isCapturing ? 50 : 56,
                        height: _isCapturing ? 50 : 56,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
                // Switch camera button
                GestureDetector(
                  onTap: (_cameras != null && _cameras!.length > 1) ? _switchCamera : null,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      Icons.flip_camera_android_rounded,
                      color: (_cameras != null && _cameras!.length > 1)
                          ? Colors.white
                          : Colors.white38,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraPreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1 / _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        // Oval guide overlay
        Container(
          width: 260, height: 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(130),
            border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 2.5),
          ),
        ),
        // Tips at bottom
        Positioned(
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: const Text(AppStrings.scanTips, style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraLoadingView() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
        SizedBox(height: 16),
        Text('Starting camera...', style: TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _buildCameraErrorView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          Text(
            _cameraErrorMessage ?? 'Camera unavailable',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
