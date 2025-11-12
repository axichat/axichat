const _deltaFileMetadataPrefix = 'dc-file-';

/// Returns the deterministic file metadata id we use to link Delta Chat
/// messages to their attachment rows in the database. Keeping the id stable
/// lets us upsert metadata if a message is rehydrated.
String deltaFileMetadataId(int messageId) =>
    '$_deltaFileMetadataPrefix$messageId';
