class DraftSaveResult {
  const DraftSaveResult({
    required this.draftId,
    required this.attachmentMetadataIds,
  });

  final int draftId;
  final List<String> attachmentMetadataIds;
}
