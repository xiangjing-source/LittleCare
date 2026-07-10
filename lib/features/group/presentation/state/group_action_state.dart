class GroupActionState {
  const GroupActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  GroupActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) => GroupActionState(
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    successMessage:
        clearMessages ? null : successMessage ?? this.successMessage,
  );
}
