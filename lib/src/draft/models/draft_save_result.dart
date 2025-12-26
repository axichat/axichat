class DraftSaveResult {
  const DraftSaveResult({
    required this.draftId,
    required this.attachmentMetadataIds,
    required this.draftCount,
  });

  final int draftId;
  final List<String> attachmentMetadataIds;
  final int draftCount;
}
