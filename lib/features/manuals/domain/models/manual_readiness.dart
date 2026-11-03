enum ManualReadiness {
  ready,
  needsPreparation,
  incomplete,
  cancelled,
  noText,
  failed,
  unreadable,
}

extension ManualReadinessPresentation on ManualReadiness {
  String get label => switch (this) {
    ManualReadiness.ready => 'Ready for questions',
    ManualReadiness.needsPreparation => 'Needs preparation',
    ManualReadiness.incomplete => 'Preparation incomplete',
    ManualReadiness.cancelled => 'Preparation cancelled',
    ManualReadiness.noText => 'No searchable text found',
    ManualReadiness.failed => 'Preparation failed',
    ManualReadiness.unreadable => 'Preparation data unreadable',
  };

  String get actionLabel => switch (this) {
    ManualReadiness.ready => 'Rebuild',
    ManualReadiness.needsPreparation => 'Prepare',
    ManualReadiness.noText => 'Try preparation again',
    ManualReadiness.incomplete ||
    ManualReadiness.cancelled ||
    ManualReadiness.failed ||
    ManualReadiness.unreadable => 'Retry preparation',
  };
}
