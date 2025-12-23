class ApiConfig {
  // Thay đổi URL này theo backend của bạn
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  
  static String get loginEndpoint => '$baseUrl/auth/login';
  static String get refreshEndpoint => '$baseUrl/auth/refresh';
  static String get registerEndpoint => '$baseUrl/users/';
  static String get resetPasswordEndpoint => '$baseUrl/auth/reset-password';
  static String get profileEndpoint => '$baseUrl/auth/me';
  static String get transactionsEndpoint => '$baseUrl/transactions/';
  static String get transactionsTimeFrameEndpoint => '$baseUrl/transactions/summary/timeframes/';
  static String get sumTransactionsEndpoint => '$baseUrl/transactions/summary';
  static String get categoriesEndpoint => '$baseUrl/categories/';
}

