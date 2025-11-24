enum RequestStatus { none, loading, success, failure }

extension RequestStatusFlags on RequestStatus {
  bool get isNone => this == RequestStatus.none;

  bool get isLoading => this == RequestStatus.loading;

  bool get isSuccess => this == RequestStatus.success;

  bool get isFailure => this == RequestStatus.failure;
}
