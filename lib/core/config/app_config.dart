/// Supported runtime environments for the application.
enum AppEnvironment { development, staging, production }

/// Centralised application-level configuration.
final class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.viennaOgdBaseUrl,
    this.requestTimeout = const Duration(seconds: 15),
    this.enableVerboseLogging = false,
  });

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    final environment = switch (envName.toLowerCase()) {
      'production' || 'prod' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };

    return AppConfig(
      appName: 'Vienna POI Explorer',
      environment: environment,
      viennaOgdBaseUrl: const String.fromEnvironment(
        'VIENNA_OGD_BASE_URL',
        defaultValue: 'https://data.wien.gv.at/daten/geo',
      ),
      enableVerboseLogging: environment == AppEnvironment.development,
    );
  }

  final String appName;
  final AppEnvironment environment;
  final String viennaOgdBaseUrl;
  final Duration requestTimeout;
  final bool enableVerboseLogging;
}
