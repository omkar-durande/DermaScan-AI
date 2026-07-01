/// DermaScan AI — String Constants
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'DermaScan AI';
  static const String appTagline = 'AI-powered skin health assistant';

  // Onboarding
  static const String onboardingTitle1 = 'Scan Your Skin';
  static const String onboardingDesc1 =
      'Use your camera to capture skin lesions for instant AI analysis';
  static const String onboardingTitle2 = 'Get Instant Analysis';
  static const String onboardingDesc2 =
      'Our AI model identifies 6 types of skin conditions with high accuracy';
  static const String onboardingTitle3 = 'Find Nearby Doctors';
  static const String onboardingDesc3 =
      'Locate dermatologists and hospitals near you for professional consultation';

  // Disclaimer
  static const String medicalDisclaimer =
      'This app is for educational purposes only. Not a substitute for professional medical advice, diagnosis, or treatment.';
  static const String remedyDisclaimer =
      'Consult a doctor before trying any home remedy. These suggestions are for informational purposes only.';

  // Auth
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue your skin health journey';
  static const String phoneTabLabel = 'Phone';
  static const String googleTabLabel = 'Google';
  static const String sendOtp = 'Send OTP';
  static const String verifyOtp = 'Verify OTP';
  static const String enterPhone = 'Enter your phone number';
  static const String enterOtp = 'Enter the 6-digit code sent to';
  static const String googleSignIn = 'Continue with Google';

  // Home
  static const String greeting = 'Hello';
  static const String totalScans = 'Total Scans';
  static const String lastScan = 'Last Scan';
  static const String streakDays = 'Streak';
  static const String recentScans = 'Recent Scans';
  static const String uvIndex = 'UV Index';
  static const String quickScan = 'Quick Scan';

  // Scan
  static const String scanTips = 'Ensure good lighting, hold steady, fill the oval';
  static const String analyzing = 'Analyzing your skin...';
  static const String lowConfidenceWarning =
      'Low confidence result — please retake the photo for a more accurate analysis';
  static const String melanomaWarning =
      '⚠️ URGENT: Melanoma detected. Please see a dermatologist immediately. Early detection saves lives.';

  // Results
  static const String detectedDisease = 'Detected Condition';
  static const String confidence = 'Confidence';
  static const String allProbabilities = 'All Probabilities';
  static const String diseaseInfo = 'About This Condition';
  static const String homeRemedies = 'Home Remedies';
  static const String findHospitals = 'Find Nearby Hospitals';
  static const String consultDoctor = 'Consult a Dermatologist';
  static const String saveToHistory = 'Save to History';
  static const String trackProgress = 'Track Treatment Progress';

  // History
  static const String scanHistory = 'Scan History';
  static const String noScansYet = 'No scans yet. Tap the scan button to get started!';
  static const String exportPdf = 'Export as PDF';

  // Treatment
  static const String treatmentProgress = 'Treatment Progress';
  static const String addTreatmentLog = 'Add Treatment Log';
  static const String improvement = 'How are you feeling?';
  static const String worse = 'Worse';
  static const String same = 'Same';
  static const String better = 'Better';

  // Hospitals
  static const String nearbyHospitals = 'Nearby Hospitals';
  static const String dermatologist = 'Dermatologist';
  static const String generalHospital = 'General Hospital';
  static const String clinic = 'Clinic';

  // UV
  static const String uvExposure = 'UV Exposure';
  static const String sunProtection = 'Sun Protection Advice';

  // Profile
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String skinType = 'Skin Type';
  static const String notifications = 'Notifications';
  static const String aboutApp = 'About';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String logout = 'Logout';

  // Errors
  static const String noInternet = 'No internet connection. Please check your network.';
  static const String serverBusy = 'Server is busy. Please try again in a moment.';
  static const String imageTooSmall = 'Image is too small. Please take a clearer photo.';
  static const String genericError = 'Something went wrong. Please try again.';
}
