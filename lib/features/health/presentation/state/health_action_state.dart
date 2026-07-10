const _unset = Object();

class HealthActionState {
  const HealthActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  HealthActionState copyWith({
    bool? isLoading,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return HealthActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          identical(errorMessage, _unset)
              ? this.errorMessage
              : errorMessage as String?,
      successMessage:
          identical(successMessage, _unset)
              ? this.successMessage
              : successMessage as String?,
    );
  }
}
