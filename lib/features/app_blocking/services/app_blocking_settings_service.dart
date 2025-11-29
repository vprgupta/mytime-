import 'package:hive/hive.dart';
import '../models/app_blocking_settings.dart';

class AppBlockingSettingsService {
  static final AppBlockingSettingsService _instance = AppBlockingSettingsService._internal();
  factory AppBlockingSettingsService() => _instance;
  AppBlockingSettingsService._internal();

  late Box<AppBlockingSettings> _settingsBox;
  AppBlockingSettings? _currentSettings;

  static const String _settingsKey = 'app_blocking_settings';

  Future<void> initialize() async {
    _settingsBox = await Hive.openBox<AppBlockingSettings>('app_blocking_settings');
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    _currentSettings = _settingsBox.get(_settingsKey);
    if (_currentSettings == null) {
      _currentSettings = AppBlockingSettings();
      await _saveSettings();
    }
  }

  Future<void> _saveSettings() async {
    if (_currentSettings != null) {
      await _settingsBox.put(_settingsKey, _currentSettings!);
    }
  }

  AppBlockingSettings get settings => _currentSettings ?? AppBlockingSettings();

  // Toggle Mode Settings
  bool get isToggleModeEnabled => settings.isToggleModeEnabled;
  
  Future<void> setToggleModeEnabled(bool enabled) async {
    _currentSettings = settings.copyWith(isToggleModeEnabled: enabled);
    await _saveSettings();
  }

  // Naming Limiter Settings
  bool get isNamingLimiterEnabled => settings.isNamingLimiterEnabled;
  String get customScreenName => settings.customScreenName;
  
  Future<void> setNamingLimiterEnabled(bool enabled) async {
    _currentSettings = settings.copyWith(isNamingLimiterEnabled: enabled);
    await _saveSettings();
  }
  
  Future<void> setCustomScreenName(String name) async {
    _currentSettings = settings.copyWith(customScreenName: name);
    await _saveSettings();
  }

  // Favorite Apps
  List<String> get favoriteApps => settings.favoriteApps;
  
  Future<void> addFavoriteApp(String packageName) async {
    final favorites = List<String>.from(settings.favoriteApps);
    if (!favorites.contains(packageName)) {
      favorites.add(packageName);
      _currentSettings = settings.copyWith(favoriteApps: favorites);
      await _saveSettings();
    }
  }
  
  Future<void> removeFavoriteApp(String packageName) async {
    final favorites = List<String>.from(settings.favoriteApps);
    favorites.remove(packageName);
    _currentSettings = settings.copyWith(favoriteApps: favorites);
    await _saveSettings();
  }

  bool isFavoriteApp(String packageName) {
    return settings.favoriteApps.contains(packageName);
  }

  // Default Duration
  int get defaultBlockDuration => settings.defaultBlockDuration;
  
  Future<void> setDefaultBlockDuration(int minutes) async {
    _currentSettings = settings.copyWith(defaultBlockDuration: minutes);
    await _saveSettings();
  }

  // Quick Actions
  bool get enableQuickActions => settings.enableQuickActions;
  
  Future<void> setQuickActionsEnabled(bool enabled) async {
    _currentSettings = settings.copyWith(enableQuickActions: enabled);
    await _saveSettings();
  }

  // Bulk Settings Update
  Future<void> updateSettings({
    bool? isToggleModeEnabled,
    bool? isNamingLimiterEnabled,
    String? customScreenName,
    List<String>? favoriteApps,
    int? defaultBlockDuration,
    bool? enableQuickActions,
  }) async {
    _currentSettings = settings.copyWith(
      isToggleModeEnabled: isToggleModeEnabled,
      isNamingLimiterEnabled: isNamingLimiterEnabled,
      customScreenName: customScreenName,
      favoriteApps: favoriteApps,
      defaultBlockDuration: defaultBlockDuration,
      enableQuickActions: enableQuickActions,
    );
    await _saveSettings();
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _currentSettings = AppBlockingSettings();
    await _saveSettings();
  }

  // Export/Import settings
  Map<String, dynamic> exportSettings() {
    return settings.toJson();
  }

  Future<void> importSettings(Map<String, dynamic> json) async {
    _currentSettings = AppBlockingSettings.fromJson(json);
    await _saveSettings();
  }
}