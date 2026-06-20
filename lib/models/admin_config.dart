class AdminConfig {
  const AdminConfig({
    this.lastUpdated,
    this.updatedBy = '',
    this.marketMessage = '',
  });

  final DateTime? lastUpdated;
  final String updatedBy;
  final String marketMessage;
}
