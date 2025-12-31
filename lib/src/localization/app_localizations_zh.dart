// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => '聊天';

  @override
  String get homeTabDrafts => '草稿';

  @override
  String get homeTabSpam => '垃圾邮件';

  @override
  String get homeTabBlocked => '已屏蔽';

  @override
  String get homeNoModules => '没有可用模块';

  @override
  String get homeRailShowMenu => '显示菜单';

  @override
  String get homeRailHideMenu => '隐藏菜单';

  @override
  String get homeRailCalendar => '日历';

  @override
  String get homeSearchPlaceholderTabs => '搜索标签页';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return '搜索$tab';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return '筛选：$filter';
  }

  @override
  String get blocklistFilterAll => '全部已屏蔽';

  @override
  String get draftsFilterAll => '所有草稿';

  @override
  String get draftsFilterAttachments => '含附件';

  @override
  String get chatsFilterAll => '所有聊天';

  @override
  String get chatsFilterContacts => '联系人';

  @override
  String get chatsFilterNonContacts => '非联系人';

  @override
  String get chatsFilterXmppOnly => '仅 XMPP';

  @override
  String get chatsFilterEmailOnly => '仅邮件';

  @override
  String get chatsFilterHidden => '已隐藏';

  @override
  String get spamFilterAll => '所有垃圾邮件';

  @override
  String get spamFilterEmail => '邮件';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => '仅直接';

  @override
  String get chatFilterAllWithContact => '全部（含联系人）';

  @override
  String get chatSearchMessages => '搜索消息';

  @override
  String get chatSearchSortNewestFirst => '最新优先';

  @override
  String get chatSearchSortOldestFirst => '最早优先';

  @override
  String get chatSearchAnySubject => '任何主题';

  @override
  String get chatSearchExcludeSubject => '排除主题';

  @override
  String get chatSearchFailed => '搜索失败';

  @override
  String get chatSearchInProgress => '正在搜索…';

  @override
  String get chatSearchEmptyPrompt => '匹配结果会显示在下方对话中。';

  @override
  String get chatSearchNoMatches => '没有匹配项。调整筛选或换个搜索词。';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '显示 # 个匹配结果。',
      one: '显示 # 个匹配结果。',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return '筛选 • $label';
  }

  @override
  String get chatSearchClose => '关闭搜索';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonClear => '清除';

  @override
  String get commonCancel => '取消';

  @override
  String get spamEmpty => '还没有垃圾邮件';

  @override
  String get spamMoveToInbox => '移到收件箱';

  @override
  String get spamMoveToastTitle => '已移动';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return '已将 $chatTitle 移回收件箱。';
  }

  @override
  String get chatSpamUpdateFailed => '更新垃圾邮件状态失败。';

  @override
  String chatSpamSent(Object chatTitle) {
    return '已将 $chatTitle 标记为垃圾邮件。';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return '已将 $chatTitle 移回收件箱。';
  }

  @override
  String get chatSpamReportedTitle => '已举报';

  @override
  String get chatSpamRestoredTitle => '已恢复';

  @override
  String get chatMembersLoading => '正在加载成员';

  @override
  String get chatMembersLoadingEllipsis => '正在加载成员…';

  @override
  String get chatAttachmentConfirmTitle => '加载附件？';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return '请只加载信任的联系人的附件。\n\n$sender 还未在你的联系人中。是否继续？';
  }

  @override
  String get chatAttachmentConfirmButton => '加载';

  @override
  String get attachmentGalleryRosterTrustLabel => '自动下载来自此用户的文件';

  @override
  String get attachmentGalleryRosterTrustHint => '你可以稍后在聊天设置中关闭。';

  @override
  String get attachmentGalleryChatTrustLabel => '始终允许此聊天中的附件';

  @override
  String get attachmentGalleryChatTrustHint => '你可以稍后在聊天设置中关闭。';

  @override
  String get attachmentGalleryRosterErrorTitle => '无法添加联系人';

  @override
  String get attachmentGalleryRosterErrorMessage => '已下载此附件一次，但自动下载仍被禁用。';

  @override
  String get attachmentGalleryErrorMessage => '无法加载附件。';

  @override
  String get attachmentGalleryAllLabel => '全部';

  @override
  String get attachmentGalleryImagesLabel => '图片';

  @override
  String get attachmentGalleryVideosLabel => '视频';

  @override
  String get attachmentGalleryFilesLabel => '文件';

  @override
  String get attachmentGallerySentLabel => '已发送';

  @override
  String get attachmentGalleryReceivedLabel => '已接收';

  @override
  String get attachmentGallerySortNameAscLabel => '名称 A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => '名称 Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel => '大小从小到大';

  @override
  String get attachmentGallerySortSizeDescLabel => '大小从大到小';

  @override
  String get chatOpenLinkTitle => '打开外部链接？';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return '你将要打开：\n$url\n\n仅在信任该站点时点击确定（主机：$host）。';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return '你将要打开：\n$url\n\n该链接包含异常或不可见字符。请仔细核对地址（主机：$host）。';
  }

  @override
  String get chatOpenLinkConfirm => '打开链接';

  @override
  String chatInvalidLink(Object url) {
    return '无效的链接：$url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return '无法打开 $host';
  }

  @override
  String get chatSaveAsDraft => '保存为草稿';

  @override
  String get chatDraftUnavailable => '暂时无法使用草稿。';

  @override
  String get chatDraftMissingContent => '请先添加消息、主题或附件再保存。';

  @override
  String get chatDraftSaved => '已保存到草稿。';

  @override
  String get chatDraftSaveFailed => '无法保存草稿，请重试。';

  @override
  String get chatAttachmentInaccessible => '所选文件无法访问。';

  @override
  String get chatAttachmentFailed => '无法添加附件。';

  @override
  String get chatAttachmentView => '查看';

  @override
  String get chatAttachmentRetry => '重试上传';

  @override
  String get chatAttachmentRemove => '移除附件';

  @override
  String get commonClose => '关闭';

  @override
  String get toastWhoopsTitle => '糟糕';

  @override
  String get toastHeadsUpTitle => '提醒';

  @override
  String get toastAllSetTitle => '完成';

  @override
  String get chatRoomMembers => '聊天室成员';

  @override
  String get chatCloseSettings => '关闭设置';

  @override
  String get chatSettings => '聊天设置';

  @override
  String get chatEmptySearch => '没有匹配项';

  @override
  String get chatEmptyMessages => '没有消息';

  @override
  String get chatComposerEmailHint => '发送邮件消息';

  @override
  String get chatComposerMessageHint => '发送消息';

  @override
  String get chatReadOnly => '只读';

  @override
  String get chatUnarchivePrompt => '取消存档后才能发送新消息。';

  @override
  String get chatEmojiPicker => '表情选择器';

  @override
  String get chatShowingDirectOnly => '仅显示直接消息';

  @override
  String get chatShowingAll => '显示全部';

  @override
  String get chatMuteNotifications => '静音通知';

  @override
  String get chatEnableNotifications => '启用通知';

  @override
  String get chatMoveToInbox => '移到收件箱';

  @override
  String get chatReportSpam => '举报垃圾信息';

  @override
  String get chatSignatureToggleLabel => '为邮件添加分享令牌页脚';

  @override
  String get chatSignatureHintEnabled => '帮助保持多收件人的邮件线程。';

  @override
  String get chatSignatureHintDisabled => '已全局禁用；回复可能无法在线程中。';

  @override
  String get chatSignatureHintWarning => '关闭可能导致线程和附件分组异常。';

  @override
  String get chatInviteRevoked => '邀请已撤销';

  @override
  String get chatInvite => '邀请';

  @override
  String get chatReactionsNone => '还没有表情回应';

  @override
  String get chatReactionsPrompt => '点按表情以添加或移除你的回应';

  @override
  String get chatReactionsPick => '选择一个表情来回应';

  @override
  String get chatActionReply => '回复';

  @override
  String get chatActionForward => '转发';

  @override
  String get chatActionResend => '重新发送';

  @override
  String get chatActionEdit => '编辑';

  @override
  String get chatActionRevoke => '撤回';

  @override
  String get chatActionCopy => '复制';

  @override
  String get chatActionShare => '分享';

  @override
  String get chatActionAddToCalendar => '添加到日历';

  @override
  String get chatCalendarTaskCopyActionLabel => '复制到日历';

  @override
  String get chatCalendarTaskImportConfirmTitle => '添加到日历？';

  @override
  String get chatCalendarTaskImportConfirmMessage => '此任务来自聊天。添加到你的日历以便管理或编辑。';

  @override
  String get chatCalendarTaskImportConfirmLabel => '添加到日历';

  @override
  String get chatCalendarTaskImportCancelLabel => '暂不';

  @override
  String get chatCalendarTaskCopyUnavailableMessage => '日历不可用。';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage => '任务已添加。';

  @override
  String get chatCalendarTaskCopySuccessMessage => '任务已复制。';

  @override
  String get chatActionDetails => '详情';

  @override
  String get chatActionSelect => '选择';

  @override
  String get chatActionReact => '回应';

  @override
  String get chatContactRenameAction => '重命名';

  @override
  String get chatContactRenameTooltip => '重命名联系人';

  @override
  String get chatContactRenameTitle => '重命名联系人';

  @override
  String get chatContactRenameDescription => '选择此联系人在 Axichat 中的显示方式。';

  @override
  String get chatContactRenamePlaceholder => '显示名称';

  @override
  String get chatContactRenameReset => '恢复默认';

  @override
  String get chatContactRenameSave => '保存';

  @override
  String get chatContactRenameSuccess => '显示名称已更新';

  @override
  String get chatContactRenameFailure => '无法重命名联系人';

  @override
  String get chatComposerSemantics => '消息输入框';

  @override
  String get draftSaved => '草稿已保存';

  @override
  String get draftErrorTitle => '糟糕';

  @override
  String get draftNoRecipients => '没有收件人';

  @override
  String get draftSubjectSemantics => '邮件主题';

  @override
  String get draftSubjectHintOptional => '主题（可选）';

  @override
  String get draftMessageSemantics => '消息正文';

  @override
  String get draftMessageHint => '消息';

  @override
  String get draftSendingStatus => '正在发送...';

  @override
  String get draftSendingEllipsis => '正在发送…';

  @override
  String get draftSend => '发送草稿';

  @override
  String get draftDiscard => '丢弃';

  @override
  String get draftSave => '保存草稿';

  @override
  String get draftAttachmentInaccessible => '所选文件不可访问。';

  @override
  String get draftAttachmentFailed => '无法添加附件。';

  @override
  String get draftDiscarded => '草稿已丢弃。';

  @override
  String get draftSendFailed => '草稿发送失败。';

  @override
  String get draftSent => '已发送';

  @override
  String draftLimitWarning(int limit, int count) {
    return '草稿同步最多保留 $limit 条草稿。你已拥有 $count 条。';
  }

  @override
  String get draftValidationNoContent => '请添加主题、消息或附件';

  @override
  String draftFileMissing(Object path) {
    return '文件在 $path 不存在。';
  }

  @override
  String get draftAttachmentPreview => '预览';

  @override
  String get draftRemoveAttachment => '移除附件';

  @override
  String get draftNoAttachments => '尚无附件';

  @override
  String get draftAttachmentsLabel => '附件';

  @override
  String get draftAddAttachment => '添加附件';

  @override
  String draftTaskDue(Object date) {
    return '截止 $date';
  }

  @override
  String get draftTaskNoSchedule => '暂无日程';

  @override
  String get draftTaskUntitled => '未命名任务';

  @override
  String get chatBack => '返回';

  @override
  String get chatErrorLabel => '错误！';

  @override
  String get chatSenderYou => '你';

  @override
  String get chatInviteAlreadyInRoom => '已在此房间。';

  @override
  String get chatInviteWrongAccount => '此邀请不适用于该账号。';

  @override
  String get chatShareNoText => '消息没有可分享的文本。';

  @override
  String get chatShareFallbackSubject => 'Axichat 消息';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return '来自 $chatTitle';
  }

  @override
  String get chatCalendarNoText => '消息没有可添加到日历的文本。';

  @override
  String get chatCalendarUnavailable => '日历当前不可用。';

  @override
  String get chatCopyNoText => '选中的消息没有可复制的文本。';

  @override
  String get chatShareSelectedNoText => '选中的消息没有可分享的文本。';

  @override
  String get chatForwardInviteForbidden => '邀请无法转发。';

  @override
  String get chatAddToCalendarNoText => '选中的消息没有可添加到日历的文本。';

  @override
  String get chatForwardDialogTitle => '转发到...';

  @override
  String get chatForwardEmailWarningTitle => 'Forward email?';

  @override
  String get chatForwardEmailWarningMessage =>
      'Forwarding email can include original headers and external image links. Choose how to send.';

  @override
  String get chatForwardEmailOptionSafe => 'Forward as new message';

  @override
  String get chatForwardEmailOptionOriginal => 'Forward original';

  @override
  String get chatComposerAttachmentWarning => '大附件会分别发送给每个收件人，可能需要更长时间送达。';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '收件人',
      one: '收件人',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel) {
    return '主题“$subject”发送给$count$recipientLabel失败。';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return '发送给$count$recipientLabel失败。';
  }

  @override
  String get chatFanOutRetry => '重试';

  @override
  String get chatSubjectSemantics => '邮件主题';

  @override
  String get chatSubjectHint => '主题';

  @override
  String get chatAttachmentTooltip => '附件';

  @override
  String get chatPinnedMessagesTooltip => 'Pinned messages';

  @override
  String get chatPinnedMessagesTitle => 'Pinned messages';

  @override
  String get chatPinMessage => 'Pin message';

  @override
  String get chatUnpinMessage => 'Unpin message';

  @override
  String get chatPinnedEmptyState => 'No pinned messages yet.';

  @override
  String get chatPinnedMissingMessage => 'Pinned message is unavailable.';

  @override
  String get chatSendMessageTooltip => '发送消息';

  @override
  String get chatBlockAction => '屏蔽';

  @override
  String get chatReactionMore => '更多';

  @override
  String get chatQuotedNoContent => '（无内容）';

  @override
  String get chatReplyingTo => '正在回复…';

  @override
  String get chatCancelReply => '取消回复';

  @override
  String get chatMessageRetracted => '（已撤回）';

  @override
  String get chatMessageEdited => '（已编辑）';

  @override
  String get chatGuestAttachmentsDisabled => '预览中已禁用附件。';

  @override
  String get chatGuestSubtitle => '访客预览 • 本地存储';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count 条更多',
      one: '+1 条更多',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => '收起';

  @override
  String recipientsSemantics(int count, Object state) {
    return '收件人 $count，$state';
  }

  @override
  String get recipientsStateCollapsed => '已收起';

  @override
  String get recipientsStateExpanded => '已展开';

  @override
  String get recipientsHintExpand => '点击展开';

  @override
  String get recipientsHintCollapse => '点击收起';

  @override
  String get recipientsHeaderTitle => '发送至...';

  @override
  String get recipientsFallbackLabel => '收件人';

  @override
  String get recipientsAddHint => '添加...';

  @override
  String get chatGuestScriptWelcome => '欢迎使用 Axichat——在一个地方处理聊天、邮件和日历。';

  @override
  String get chatGuestScriptExternalQuestion => '看起来很简洁。我能给不用 Axichat 的人发消息吗？';

  @override
  String get chatGuestScriptExternalAnswer =>
      '可以——把聊天格式的邮件发送到 Gmail、Outlook、Tuta 等。如果双方都用 Axichat，还能获得群聊、表情反馈、送达回执等。';

  @override
  String get chatGuestScriptOfflineQuestion => '离线或访客模式可以用吗？';

  @override
  String get chatGuestScriptOfflineAnswer =>
      '可以——离线功能内置，日历在访客模式下也能在无账号、无网络时工作。';

  @override
  String get chatGuestScriptKeepUpQuestion => '它如何帮助我跟进所有事情？';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      '我们的日历支持自然语言排程、艾森豪威尔矩阵、拖拽和提醒，让你专注重要事项。';

  @override
  String calendarParserUnavailable(Object errorType) {
    return '解析不可用（$errorType）';
  }

  @override
  String get calendarAddTaskTitle => '添加任务';

  @override
  String get calendarTaskNameRequired => '任务名称 *';

  @override
  String get calendarTaskNameHint => '任务名称';

  @override
  String get calendarDescriptionHint => '描述（可选）';

  @override
  String get calendarLocationHint => '位置（可选）';

  @override
  String get calendarScheduleLabel => '安排';

  @override
  String get calendarDeadlineLabel => '截止日期';

  @override
  String get calendarRepeatLabel => '重复';

  @override
  String get calendarCancel => '取消';

  @override
  String get calendarAddTaskAction => '添加任务';

  @override
  String get calendarSelectionMode => '选择模式';

  @override
  String get calendarExit => '退出';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 # 个任务',
      one: '已选 # 个任务',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => '操作';

  @override
  String get calendarSetPriority => '设置优先级';

  @override
  String get calendarClearSelection => '清除选择';

  @override
  String get calendarExportSelected => '导出所选';

  @override
  String get calendarDeleteSelected => '删除所选';

  @override
  String get calendarBatchEdit => '批量编辑';

  @override
  String get calendarBatchTitle => '标题';

  @override
  String get calendarBatchTitleHint => '为所选任务设置标题';

  @override
  String get calendarBatchDescription => '描述';

  @override
  String get calendarBatchDescriptionHint => '设置描述（留空即清除）';

  @override
  String get calendarBatchLocation => '位置';

  @override
  String get calendarBatchLocationHint => '设置位置（留空即清除）';

  @override
  String get calendarApplyChanges => '应用更改';

  @override
  String get calendarAdjustTime => '调整时间';

  @override
  String get calendarSelectionRequired => '在应用更改前请选择任务。';

  @override
  String get calendarSelectionNone => '请先选择要导出的任务。';

  @override
  String get calendarSelectionChangesApplied => '更改已应用到所选任务。';

  @override
  String get calendarSelectionNoPending => '没有待应用的更改。';

  @override
  String get calendarSelectionTitleBlank => '标题不能为空。';

  @override
  String get calendarExportReady => '导出已准备好分享。';

  @override
  String calendarExportFailed(Object error) {
    return '无法导出所选任务：$error';
  }

  @override
  String get commonBack => '返回';

  @override
  String get composeTitle => '撰写';

  @override
  String get draftComposeMessage => '撰写消息';

  @override
  String get draftCompose => '撰写';

  @override
  String get draftNewMessage => '新消息';

  @override
  String get draftRestore => '还原';

  @override
  String get draftMinimize => '最小化';

  @override
  String get draftExpand => '展开';

  @override
  String get draftExitFullscreen => '退出全屏';

  @override
  String get draftCloseComposer => '关闭编辑器';

  @override
  String get draftsEmpty => '尚无草稿';

  @override
  String get draftsDeleteConfirm => '删除草稿？';

  @override
  String get draftNoSubject => '（无主题）';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位收件人',
      one: '$count 位收件人',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => '正在创建您的账户…';

  @override
  String get authSecuringLogin => '正在保护您的登录…';

  @override
  String get authLoggingIn => '正在登录…';

  @override
  String get authToggleSignup => '新用户？注册';

  @override
  String get authToggleLogin => '已有账户？登录';

  @override
  String get authGuestCalendarCta => '试用日历（访客模式）';

  @override
  String get authLogin => '登录';

  @override
  String get authRememberMeLabel => '在此设备上记住我';

  @override
  String get authSignUp => '注册';

  @override
  String get authToggleSelected => '当前选择';

  @override
  String authToggleSelectHint(Object label) {
    return '点击以选择 $label';
  }

  @override
  String get authUsername => '用户名';

  @override
  String get authUsernameRequired => '请输入用户名';

  @override
  String get authUsernameRules => '4-20 个字母或数字，可包含“.”、“_”和“-”。';

  @override
  String get authUsernameCaseInsensitive => '不区分大小写';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordConfirm => '确认密码';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String authPasswordMaxLength(Object max) {
    return '长度必须不超过 $max 个字符';
  }

  @override
  String get authPasswordsMismatch => '两次密码不一致';

  @override
  String get authPasswordPending => '正在检查密码安全性';

  @override
  String get authSignupPending => '正在注册';

  @override
  String get authLoginPending => '正在登录';

  @override
  String get signupTitle => '注册';

  @override
  String get signupStepUsername => '选择用户名';

  @override
  String get signupStepPassword => '创建密码';

  @override
  String get signupStepCaptcha => '验证验证码';

  @override
  String get signupStepSetup => '设置';

  @override
  String signupErrorPrefix(Object message) {
    return '错误：$message';
  }

  @override
  String get signupCaptchaUnavailable => '验证码不可用';

  @override
  String get signupCaptchaChallenge => '验证码挑战';

  @override
  String get signupCaptchaFailed => '验证码加载失败。请刷新重试。';

  @override
  String get signupCaptchaLoading => '正在加载验证码';

  @override
  String get signupCaptchaInstructions => '请输入验证码图片中的字符。';

  @override
  String get signupCaptchaReload => '重新加载验证码';

  @override
  String get signupCaptchaReloadHint => '看不清时获取新的验证码图片。';

  @override
  String get signupCaptchaPlaceholder => '输入上方文字';

  @override
  String get signupCaptchaValidation => '输入图片中的文字';

  @override
  String get signupContinue => '继续';

  @override
  String get signupProgressLabel => '注册进度';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
    return '第 $current/$total 步：$currentLabel。已完成 $percent%。';
  }

  @override
  String get signupProgressSection => '账户设置';

  @override
  String get signupPasswordStrength => '密码强度';

  @override
  String get signupPasswordBreached => '该密码出现在泄露的数据库中。';

  @override
  String get signupStrengthNone => '无';

  @override
  String get signupStrengthWeak => '弱';

  @override
  String get signupStrengthMedium => '中';

  @override
  String get signupStrengthStronger => '较强';

  @override
  String get signupRiskAcknowledgement => '我了解风险';

  @override
  String get signupRiskError => '请勾选上方的复选框以继续。';

  @override
  String get signupRiskAllowBreach => '即使此密码出现在泄漏中也允许使用。';

  @override
  String get signupRiskAllowWeak => '即使此密码被视为弱也允许使用。';

  @override
  String get signupCaptchaErrorMessage => '无法加载验证码。\n请点击刷新重试。';

  @override
  String get signupAvatarRenderError => '无法渲染该头像。';

  @override
  String get signupAvatarLoadError => '无法加载该头像。';

  @override
  String get signupAvatarReadError => '无法读取该图像。';

  @override
  String get signupAvatarOpenError => '无法打开该文件。';

  @override
  String get signupAvatarInvalidImage => '该文件不是有效的图像。';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return '头像大小必须小于 $kilobytes KB。';
  }

  @override
  String get signupAvatarProcessError => '无法处理该图像。';

  @override
  String get signupAvatarEdit => '编辑头像';

  @override
  String get signupAvatarUploadImage => '上传图片';

  @override
  String get signupAvatarUpload => '上传';

  @override
  String get signupAvatarShuffle => '随机默认头像';

  @override
  String get signupAvatarMenuDescription => '创建 XMPP 账号后才会发布头像。';

  @override
  String get avatarSaveAvatar => '保存头像';

  @override
  String get signupAvatarBackgroundColor => '背景颜色';

  @override
  String get signupAvatarDefaultsTitle => '默认头像';

  @override
  String get signupAvatarCategoryAbstract => '抽象';

  @override
  String get signupAvatarCategoryScience => '科学';

  @override
  String get signupAvatarCategorySports => '体育';

  @override
  String get signupAvatarCategoryMusic => '音乐';

  @override
  String get notificationsRestartTitle => '重启应用以启用通知';

  @override
  String get notificationsRestartSubtitle => '必要权限已授予';

  @override
  String get notificationsMessageToggle => '消息通知';

  @override
  String get notificationsRequiresRestart => '需要重启';

  @override
  String get notificationsDialogTitle => '启用消息通知';

  @override
  String get notificationsDialogIgnore => '忽略';

  @override
  String get notificationsDialogContinue => '继续';

  @override
  String get notificationsDialogDescription => '聊天随时可以静音。';

  @override
  String get calendarAdjustStartMinus => '开始 -15 分';

  @override
  String get calendarAdjustStartPlus => '开始 +15 分';

  @override
  String get calendarAdjustEndMinus => '结束 -15 分';

  @override
  String get calendarAdjustEndPlus => '结束 +15 分';

  @override
  String get calendarCopyToClipboardAction => '复制到剪贴板';

  @override
  String calendarCopyLocation(Object location) {
    return '地点：$location';
  }

  @override
  String get calendarTaskCopied => '任务已复制';

  @override
  String get calendarTaskCopiedClipboard => '任务已复制到剪贴板';

  @override
  String get calendarCopyTask => '复制任务';

  @override
  String get calendarDeleteTask => '删除任务';

  @override
  String get calendarSelectionNoneShort => '未选择任务。';

  @override
  String get calendarSelectionMixedRecurrence => '任务的重复设置不同。更改将应用于所有选中的任务。';

  @override
  String get calendarSelectionNoTasksHint => '未选择任务。请在日历中使用“选择”来挑选要编辑的任务。';

  @override
  String get calendarSelectionRemove => '从选择中移除';

  @override
  String get calendarQuickTaskHint => '快捷任务（例如：“下午2点在101室开会”）';

  @override
  String get calendarAdvancedHide => '隐藏高级选项';

  @override
  String get calendarAdvancedShow => '显示高级选项';

  @override
  String get calendarUnscheduledTitle => '未安排的任务';

  @override
  String get calendarUnscheduledEmptyLabel => '暂无未安排的任务';

  @override
  String get calendarUnscheduledEmptyHint => '你添加的任务会显示在这里';

  @override
  String get calendarRemindersTitle => '提醒';

  @override
  String get calendarRemindersEmptyLabel => '暂时没有提醒';

  @override
  String get calendarRemindersEmptyHint => '添加截止时间即可创建提醒';

  @override
  String get calendarNothingHere => '这里还没有内容';

  @override
  String get calendarTaskNotFound => '未找到任务';

  @override
  String get calendarDayEventsTitle => '当天事件';

  @override
  String get calendarDayEventsEmpty => '此日期没有日程事件';

  @override
  String get calendarDayEventsAdd => '添加日程事件';

  @override
  String get accessibilityNewContactLabel => '联系地址';

  @override
  String get accessibilityNewContactHint => 'someone@example.com';

  @override
  String get accessibilityStartChat => '开始聊天';

  @override
  String get accessibilityStartChatHint => '提交此地址以开始对话。';

  @override
  String get accessibilityMessagesEmpty => '暂无消息';

  @override
  String get accessibilityMessageNoContent => '无消息内容';

  @override
  String get accessibilityActionsTitle => '操作';

  @override
  String get accessibilityReadNewMessages => '阅读新消息';

  @override
  String get accessibilityUnreadSummaryDescription => '专注于包含未读消息的会话';

  @override
  String get accessibilityStartNewChat => '开始新的聊天';

  @override
  String get accessibilityStartNewChatDescription => '选择联系人或输入地址';

  @override
  String get accessibilityInvitesTitle => '邀请';

  @override
  String get accessibilityPendingInvites => '等待中的邀请';

  @override
  String get accessibilityAcceptInvite => '接受邀请';

  @override
  String get accessibilityInviteAccepted => '已接受邀请';

  @override
  String get accessibilityInviteDismissed => '已拒绝邀请';

  @override
  String get accessibilityInviteUpdateFailed => '无法更新邀请';

  @override
  String get accessibilityUnreadEmpty => '没有未读会话';

  @override
  String get accessibilityInvitesEmpty => '没有待处理的邀请';

  @override
  String get accessibilityMessagesTitle => '消息';

  @override
  String get accessibilityNoConversationSelected => '未选择会话';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return '$name 的消息';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
    return '$sender 于 $timestamp：$body';
  }

  @override
  String get accessibilityMessageSent => '消息已发送。';

  @override
  String get accessibilityDiscardWarning => '再次按下 Escape 以放弃消息并关闭此步骤。';

  @override
  String get accessibilityDraftLoaded => '草稿已加载。按 Escape 退出或保存以保留更改。';

  @override
  String accessibilityDraftLabel(Object id) {
    return '草稿 $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return '发给 $recipients 的草稿';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return '来自 $sender 的新消息，时间 $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return '附件：$filename';
  }

  @override
  String get accessibilityAttachmentGeneric => '附件';

  @override
  String get accessibilityUploadAvailable => '上传可用';

  @override
  String get accessibilityUnknownContact => '未知联系人';

  @override
  String get accessibilityChooseContact => '选择联系人';

  @override
  String get accessibilityUnreadConversations => '未读会话';

  @override
  String get accessibilityStartNewAddress => '输入新地址';

  @override
  String accessibilityConversationWith(Object name) {
    return '与 $name 的对话';
  }

  @override
  String get accessibilityConversationLabel => '对话';

  @override
  String get accessibilityDialogLabel => '辅助功能操作对话框';

  @override
  String get accessibilityDialogHint =>
      '按 Tab 查看快捷键说明，在列表中使用方向键，按住 Shift 加方向键在组之间移动，或按 Escape 退出。';

  @override
  String get accessibilityNoActionsAvailable => '当前没有可用操作';

  @override
  String accessibilityBreadcrumbLabel(
      Object position, Object total, Object label) {
    return '第 $position/$total 步：$label。激活以跳转到此步骤。';
  }

  @override
  String get accessibilityShortcutOpenMenu => '打开菜单';

  @override
  String get accessibilityShortcutBack => '后退一步或关闭';

  @override
  String get accessibilityShortcutNextFocus => '下一个焦点目标';

  @override
  String get accessibilityShortcutPreviousFocus => '上一个焦点目标';

  @override
  String get accessibilityShortcutActivateItem => '激活项目';

  @override
  String get accessibilityShortcutNextItem => '下一个项目';

  @override
  String get accessibilityShortcutPreviousItem => '上一个项目';

  @override
  String get accessibilityShortcutNextGroup => '下一个分组';

  @override
  String get accessibilityShortcutPreviousGroup => '上一个分组';

  @override
  String get accessibilityShortcutFirstItem => '第一个项目';

  @override
  String get accessibilityShortcutLastItem => '最后一个项目';

  @override
  String get accessibilityKeyboardShortcutsTitle => '键盘快捷键';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return '键盘快捷键：$description';
  }

  @override
  String get accessibilityTextFieldHint => '输入文本。按 Tab 前进，或按 Escape 返回或关闭菜单。';

  @override
  String get accessibilityComposerPlaceholder => '输入消息';

  @override
  String accessibilityRecipientLabel(Object name) {
    return '收件人 $name';
  }

  @override
  String get accessibilityRecipientRemoveHint => '按退格或删除键移除';

  @override
  String get accessibilityMessageActionsLabel => '消息操作';

  @override
  String get accessibilityMessageActionsHint => '保存为草稿或发送此消息';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return '第 $position 条消息，共 $total 条';
  }

  @override
  String get accessibilityNoMessages => '没有消息';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return '来自 $sender 于 $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return '来自 $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      '使用方向键在消息间移动。按住 Shift 加方向键切换分组。按 Escape 退出。';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return '$section 分区，包含 $count 项';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return '操作列表，共 $count 项';
  }

  @override
  String get accessibilityActionListHint =>
      '使用方向键移动，按住 Shift 加方向键切换分组，Home/End 跳转，Enter 激活，Escape 退出。';

  @override
  String accessibilityActionItemPosition(
      Object position, Object total, Object section) {
    return '$section 中的第 $position 个项目，共 $total 个';
  }

  @override
  String get accessibilityActionReadOnlyHint => '使用方向键浏览列表';

  @override
  String get accessibilityActionActivateHint => '按 Enter 激活';

  @override
  String get accessibilityDismissHighlight => '关闭提示';

  @override
  String get accessibilityNeedsAttention => '需要关注';

  @override
  String get profileTitle => '个人资料';

  @override
  String get profileJidDescription =>
      '这是你的 Jabber ID，由用户名和域名组成，是你在 XMPP 网络中的唯一地址。';

  @override
  String get profileResourceDescription =>
      '这是你的 XMPP 资源。每台设备都有自己的资源，因此手机和电脑的在线状态可以不同。';

  @override
  String get profileStatusPlaceholder => '状态消息';

  @override
  String get profileArchives => '查看存档';

  @override
  String get profileEditAvatar => '编辑头像';

  @override
  String get profileLinkedEmailAccounts => 'Email accounts';

  @override
  String get profileChangePassword => '更改密码';

  @override
  String get profileDeleteAccount => '删除账户';

  @override
  String get termsAcceptLabel => '我接受条款和条件';

  @override
  String get termsAgreementPrefix => '您同意我们的';

  @override
  String get termsAgreementTerms => '条款';

  @override
  String get termsAgreementAnd => ' 和 ';

  @override
  String get termsAgreementPrivacy => '隐私政策';

  @override
  String get termsAgreementError => '你必须接受条款和条件';

  @override
  String get commonContinue => '继续';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRemove => '移除';

  @override
  String get commonSend => '发送';

  @override
  String get commonDismiss => '关闭';

  @override
  String get settingsSectionImportant => '重要';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeModeSystem => '系统';

  @override
  String get settingsThemeModeLight => '浅色';

  @override
  String get settingsThemeModeDark => '深色';

  @override
  String get settingsColorScheme => '配色方案';

  @override
  String get settingsColorfulAvatars => '彩色头像';

  @override
  String get settingsColorfulAvatarsDescription => '为每个头像生成不同的背景颜色。';

  @override
  String get settingsLowMotion => '低动效';

  @override
  String get settingsLowMotionDescription => '禁用大部分动画，更适合性能较慢的设备。';

  @override
  String get settingsSectionChats => '聊天';

  @override
  String get settingsMessageStorageTitle => '消息存储';

  @override
  String get settingsMessageStorageSubtitle => '本地保留设备副本；仅服务器模式从存档查询。';

  @override
  String get settingsMessageStorageLocal => '本地';

  @override
  String get settingsMessageStorageServerOnly => '仅服务器';

  @override
  String get settingsMuteNotifications => '静音通知';

  @override
  String get settingsMuteNotificationsDescription => '停止接收消息通知。';

  @override
  String get settingsNotificationPreviews => '通知预览';

  @override
  String get settingsNotificationPreviewsDescription => '在通知和锁屏上显示消息内容。';

  @override
  String get settingsReadReceipts => '发送已读回执';

  @override
  String get settingsTypingIndicators => '发送正在输入指示';

  @override
  String get settingsTypingIndicatorsDescription => '让聊天中的其他人看到你正在输入。';

  @override
  String get settingsShareTokenFooter => '包含共享令牌页脚';

  @override
  String get settingsShareTokenFooterDescription =>
      '有助于保持多收件人邮件线程和附件关联。关闭可能导致线程断裂。';

  @override
  String get authCustomServerTitle => '自定义服务器';

  @override
  String get authCustomServerDescription =>
      '覆盖 XMPP/SMTP 端点或启用 DNS 查询。留空以使用默认值。';

  @override
  String get authCustomServerDomainOrIp => '域名或 IP';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => '使用 DNS';

  @override
  String get authCustomServerUseSrv => '使用 SRV';

  @override
  String get authCustomServerRequireDnssec => '需要 DNSSEC';

  @override
  String get authCustomServerXmppHostPlaceholder => 'XMPP 主机（可选）';

  @override
  String get authCustomServerPortPlaceholder => '端口';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'SMTP 主机（可选）';

  @override
  String get authCustomServerImapHostPlaceholder => 'IMAP 主机（可选）';

  @override
  String get authCustomServerApiPortPlaceholder => 'API 端口';

  @override
  String get authCustomServerReset => '重置为 axi.im';

  @override
  String get authCustomServerOpenSettings => '打开自定义服务器设置';

  @override
  String get authCustomServerAdvancedHint => '高级服务器选项会保持隐藏，直到你点击用户名后缀。';

  @override
  String get authUnregisterTitle => '注销';

  @override
  String get authUnregisterConfirmTitle => 'Delete account?';

  @override
  String get authUnregisterConfirmMessage =>
      'This will permanently delete your account and local data. This cannot be undone.';

  @override
  String get authUnregisterConfirmAction => 'Delete account';

  @override
  String get authUnregisterProgressLabel => '正在等待删除账户';

  @override
  String get authPasswordPlaceholder => '密码';

  @override
  String get authPasswordCurrentPlaceholder => '旧密码';

  @override
  String get authPasswordNewPlaceholder => '新密码';

  @override
  String get authPasswordConfirmNewPlaceholder => '确认新密码';

  @override
  String get authChangePasswordProgressLabel => '正在等待修改密码';

  @override
  String get authLogoutTitle => '退出登录';

  @override
  String get authLogoutNormal => '退出登录';

  @override
  String get authLogoutNormalDescription => '退出此账户。';

  @override
  String get authLogoutBurn => '销毁账户';

  @override
  String get authLogoutBurnDescription => '退出并清除此账户的本地数据。';

  @override
  String get chatAttachmentBlockedTitle => '附件已被阻止';

  @override
  String get chatAttachmentBlockedDescription => '仅在信任未知联系人时加载附件。你确认后我们才会获取。';

  @override
  String get chatAttachmentLoad => '加载附件';

  @override
  String get chatAttachmentUnavailable => '附件不可用';

  @override
  String get chatAttachmentSendFailed => '无法发送附件。';

  @override
  String get chatAttachmentRetryUpload => '重试上传';

  @override
  String get chatAttachmentRemoveAttachment => '移除附件';

  @override
  String get chatAttachmentStatusUploading => '正在上传附件…';

  @override
  String get chatAttachmentStatusQueued => '等待发送';

  @override
  String get chatAttachmentStatusFailed => '上传失败';

  @override
  String get chatAttachmentLoading => '正在加载附件';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return '正在加载 $percent';
  }

  @override
  String get chatAttachmentDownload => '下载附件';

  @override
  String get chatAttachmentDownloadAndOpen => '下载并打开';

  @override
  String get chatAttachmentDownloadAndSave => '下载并保存';

  @override
  String get chatAttachmentDownloadAndShare => '下载并分享';

  @override
  String get chatAttachmentExportTitle => '保存附件？';

  @override
  String get chatAttachmentExportMessage =>
      '这会将附件复制到共享存储。导出内容未加密，可能会被其他应用读取。继续？';

  @override
  String get chatAttachmentExportConfirm => '保存';

  @override
  String get chatAttachmentExportCancel => '取消';

  @override
  String get chatMediaMetadataWarningTitle => '媒体可能包含元数据';

  @override
  String get chatMediaMetadataWarningMessage => '照片和视频可能包含位置和设备信息。继续？';

  @override
  String get chatNotificationPreviewOptionInherit => '使用应用设置';

  @override
  String get chatNotificationPreviewOptionShow => '始终显示预览';

  @override
  String get chatNotificationPreviewOptionHide => '始终隐藏预览';

  @override
  String get chatAttachmentUnavailableDevice => '此设备上已无法获取该附件';

  @override
  String get chatAttachmentInvalidLink => '无效的附件链接';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return '无法打开 $target';
  }

  @override
  String get chatAttachmentTypeMismatchTitle => 'Attachment type mismatch';

  @override
  String chatAttachmentTypeMismatchMessage(Object declared, Object detected) {
    return 'This attachment says it is $declared, but the file looks like $detected. Opening it could be unsafe. Continue?';
  }

  @override
  String get chatAttachmentTypeMismatchConfirm => 'Open anyway';

  @override
  String get chatAttachmentHighRiskTitle => 'Potentially unsafe file';

  @override
  String get chatAttachmentHighRiskMessage =>
      'This file type can be dangerous to open. We recommend saving it and scanning it before opening. Continue?';

  @override
  String get chatAttachmentUnknownSize => '大小未知';

  @override
  String get chatAttachmentNotDownloadedYet => 'Not downloaded yet';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message（$fileName）';
  }

  @override
  String get chatAttachmentMenuHint => '打开菜单以查看更多操作。';

  @override
  String get accessibilityActionsLabel => '辅助功能操作';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return '辅助功能操作（$shortcut）';
  }

  @override
  String get shorebirdUpdateAvailable => '有可用更新：请注销并重新启动应用。';

  @override
  String get calendarEditTaskTitle => '编辑任务';

  @override
  String get calendarDateTimeLabel => '日期和时间';

  @override
  String get calendarSelectDate => '选择日期';

  @override
  String get calendarSelectTime => '选择时间';

  @override
  String get calendarDurationLabel => '时长';

  @override
  String get calendarSelectDuration => '选择时长';

  @override
  String get calendarAddToCriticalPath => '添加到关键路径';

  @override
  String get calendarNoCriticalPathMembership => '不在任何关键路径中';

  @override
  String get calendarGuestTitle => '访客日历';

  @override
  String get calendarGuestBanner => '访客模式 - 不同步';

  @override
  String get calendarGuestModeLabel => '访客模式';

  @override
  String get calendarGuestModeDescription => '登录以同步任务并启用提醒。';

  @override
  String get calendarNoTasksForDate => '此日期没有任务';

  @override
  String get calendarTapToCreateTask => '点击 + 创建新任务';

  @override
  String get calendarQuickStats => '快速统计';

  @override
  String get calendarDueReminders => '到期提醒';

  @override
  String get calendarNextTaskLabel => '下一项任务';

  @override
  String get calendarNone => '无';

  @override
  String get calendarViewLabel => '视图';

  @override
  String get calendarViewDay => '日';

  @override
  String get calendarViewWeek => '周';

  @override
  String get calendarViewMonth => '月';

  @override
  String get calendarPreviousDate => '上一日期';

  @override
  String get calendarNextDate => '下一日期';

  @override
  String calendarPreviousUnit(Object unit) {
    return '上一$unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return '下一$unit';
  }

  @override
  String get calendarToday => '今天';

  @override
  String get calendarUndo => '撤销';

  @override
  String get calendarRedo => '重做';

  @override
  String get calendarOpeningCreator => '正在打开任务创建器...';

  @override
  String calendarWeekOf(Object date) {
    return '本周 $date';
  }

  @override
  String get calendarStatusCompleted => '已完成';

  @override
  String get calendarStatusOverdue => '已过期';

  @override
  String get calendarStatusDueSoon => '即将到期';

  @override
  String get calendarStatusPending => '待处理';

  @override
  String get calendarTaskCompletedMessage => '任务已完成！';

  @override
  String get calendarTaskUpdatedMessage => '任务已更新！';

  @override
  String get calendarErrorTitle => '错误';

  @override
  String get calendarErrorTaskNotFound => '未找到任务';

  @override
  String get calendarErrorTitleEmpty => '标题不能为空';

  @override
  String get calendarErrorTitleTooLong => '标题过长';

  @override
  String get calendarErrorDescriptionTooLong => '描述过长';

  @override
  String get calendarErrorInputInvalid => '输入无效';

  @override
  String get calendarErrorAddFailed => '添加任务失败';

  @override
  String get calendarErrorUpdateFailed => '更新任务失败';

  @override
  String get calendarErrorDeleteFailed => '删除任务失败';

  @override
  String get calendarErrorNetwork => '网络错误';

  @override
  String get calendarErrorStorage => '存储错误';

  @override
  String get calendarErrorUnknown => '未知错误';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonOpen => '打开';

  @override
  String get commonSelect => '选择';

  @override
  String get commonExport => '导出';

  @override
  String get commonFavorite => '收藏';

  @override
  String get commonUnfavorite => '取消收藏';

  @override
  String get commonArchive => '存档';

  @override
  String get commonUnarchive => '取消存档';

  @override
  String get commonShow => '显示';

  @override
  String get commonHide => '隐藏';

  @override
  String get blocklistBlockUser => '屏蔽用户';

  @override
  String get blocklistWaitingForUnblock => '等待解除屏蔽';

  @override
  String get blocklistUnblockAll => '全部解除屏蔽';

  @override
  String get blocklistUnblock => '解除屏蔽';

  @override
  String get blocklistBlock => '屏蔽';

  @override
  String get blocklistAddTooltip => '添加到屏蔽列表';

  @override
  String get mucChangeNickname => '更改昵称';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return '更改昵称（当前：$current）';
  }

  @override
  String get mucLeaveRoom => '离开房间';

  @override
  String get mucNoMembers => '暂无成员';

  @override
  String get mucInviteUsers => '邀请用户';

  @override
  String get mucSendInvites => '发送邀请';

  @override
  String get mucChangeNicknameTitle => '更改昵称';

  @override
  String get mucEnterNicknamePlaceholder => '输入昵称';

  @override
  String get mucUpdateNickname => '更新';

  @override
  String get mucMembersTitle => '成员';

  @override
  String get mucInviteUser => '邀请用户';

  @override
  String get mucSectionOwners => '所有者';

  @override
  String get mucSectionAdmins => '管理员';

  @override
  String get mucSectionModerators => '版主';

  @override
  String get mucSectionMembers => '成员';

  @override
  String get mucSectionVisitors => '访客';

  @override
  String get mucRoleOwner => '所有者';

  @override
  String get mucRoleAdmin => '管理员';

  @override
  String get mucRoleMember => '成员';

  @override
  String get mucRoleVisitor => '访客';

  @override
  String get mucRoleModerator => '版主';

  @override
  String get mucActionKick => '移出';

  @override
  String get mucActionBan => '封禁';

  @override
  String get mucActionMakeMember => '设为成员';

  @override
  String get mucActionMakeAdmin => '设为管理员';

  @override
  String get mucActionMakeOwner => '设为所有者';

  @override
  String get mucActionGrantModerator => '授予版主';

  @override
  String get mucActionRevokeModerator => '撤销版主';

  @override
  String get chatsEmptyList => '暂时没有聊天';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return '删除聊天：$chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption => '永久删除消息';

  @override
  String get chatsDeleteSuccess => '聊天已删除';

  @override
  String get chatsExportNoContent => '没有可导出的文本内容';

  @override
  String get chatsExportShareText => '来自 Axichat 的聊天导出';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return '与 $chatTitle 的聊天';
  }

  @override
  String get chatsExportSuccess => '聊天已导出';

  @override
  String get chatsExportFailure => '无法导出聊天';

  @override
  String get chatExportWarningTitle => '导出聊天记录？';

  @override
  String get chatExportWarningMessage => '聊天导出未加密，可能会被其他应用或云服务读取。继续？';

  @override
  String get chatsArchivedRestored => '聊天已恢复';

  @override
  String get chatsArchivedHint => '聊天已存档（个人资料 → 已存档聊天）';

  @override
  String get chatsVisibleNotice => '聊天已重新可见';

  @override
  String get chatsHiddenNotice => '聊天已隐藏（使用筛选显示）';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 条未读消息',
      zero: '没有未读消息',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint => '点击取消选择聊天';

  @override
  String get chatsSemanticsSelectHint => '点击选择聊天';

  @override
  String get chatsSemanticsOpenHint => '点击打开聊天';

  @override
  String get chatsHideActions => '隐藏聊天操作';

  @override
  String get chatsShowActions => '显示聊天操作';

  @override
  String get chatsSelectedLabel => '聊天已选择';

  @override
  String get chatsSelectLabel => '选择聊天';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle => '没有可导出的消息';

  @override
  String get chatSelectionExportEmptyMessage => '选择包含文本内容的聊天';

  @override
  String get chatSelectionExportShareText => '来自 Axichat 的聊天导出';

  @override
  String get chatSelectionExportShareSubject => 'Axichat 聊天导出';

  @override
  String get chatSelectionExportReadyTitle => '导出就绪';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已分享 # 个聊天',
      one: '已分享 # 个聊天',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => '导出失败';

  @override
  String get chatSelectionExportFailedMessage => '无法导出所选聊天';

  @override
  String get chatSelectionDeleteConfirmTitle => '删除聊天？';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将删除 # 个聊天及其全部消息，无法恢复。',
      one: '将删除 1 个聊天及其全部消息，无法恢复。',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => '创建群聊';

  @override
  String get chatsRoomLabel => '房间';

  @override
  String get chatsCreateChatRoomTitle => '创建聊天室';

  @override
  String get chatsRoomNamePlaceholder => '名称';

  @override
  String get chatsArchiveTitle => '存档';

  @override
  String get chatsArchiveEmpty => '暂无已存档聊天';

  @override
  String calendarTileNow(Object title) {
    return '现在：$title';
  }

  @override
  String calendarTileNext(Object title) {
    return '接下来：$title';
  }

  @override
  String get calendarTileNone => '没有即将进行的任务';

  @override
  String get calendarViewDayShort => '日';

  @override
  String get calendarViewWeekShort => '周';

  @override
  String get calendarViewMonthShort => '月';

  @override
  String get calendarShowCompleted => '显示已完成';

  @override
  String get calendarHideCompleted => '隐藏已完成';

  @override
  String get rosterAddTooltip => '添加到联系人';

  @override
  String get rosterAddLabel => '联系人';

  @override
  String get rosterAddTitle => '添加联系人';

  @override
  String get rosterEmpty => '暂无联系人';

  @override
  String get rosterCompose => '撰写';

  @override
  String rosterRemoveConfirm(Object jid) {
    return '将 $jid 从联系人中移除？';
  }

  @override
  String get rosterInvitesEmpty => '暂无邀请';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return '拒绝来自 $jid 的邀请？';
  }

  @override
  String get rosterAddContactTooltip => '添加联系人';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => '请输入有效的 JID';

  @override
  String get sessionCapabilityChat => '聊天';

  @override
  String get sessionCapabilityEmail => '邮件';

  @override
  String get sessionCapabilityStatusConnected => '已连接';

  @override
  String get sessionCapabilityStatusConnecting => '正在连接';

  @override
  String get sessionCapabilityStatusError => '错误';

  @override
  String get sessionCapabilityStatusOffline => '离线';

  @override
  String get sessionCapabilityStatusOff => '关闭';

  @override
  String get sessionCapabilityStatusSyncing => '同步中';

  @override
  String get authChangePasswordPending => '正在更新密码...';

  @override
  String get authEndpointAdvancedHint => '高级选项';

  @override
  String get authEndpointApiPortPlaceholder => 'API 端口';

  @override
  String get authEndpointDescription => '为此账户配置 XMPP/SMTP 端点。';

  @override
  String get authEndpointDomainPlaceholder => '域名';

  @override
  String get authEndpointPortPlaceholder => '端口';

  @override
  String get authEndpointRequireDnssecLabel => '需要 DNSSEC';

  @override
  String get authEndpointReset => '重置';

  @override
  String get authEndpointSmtpHostPlaceholder => 'SMTP 主机';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => '端点配置';

  @override
  String get authEndpointUseDnsLabel => '使用 DNS';

  @override
  String get authEndpointUseSrvLabel => '使用 SRV';

  @override
  String get authEndpointXmppHostPlaceholder => 'XMPP 主机';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => '正在注销...';

  @override
  String calendarAddTaskError(Object details) {
    return '无法添加任务：$details';
  }

  @override
  String get calendarBackToCalendar => '返回日历';

  @override
  String get calendarCriticalPathAddTask => '添加任务';

  @override
  String get calendarCriticalPathAddToTitle => '添加到关键路径';

  @override
  String get calendarCriticalPathCreatePrompt => '创建关键路径以开始';

  @override
  String get calendarCriticalPathDragHint => '拖动任务以重新排序';

  @override
  String get calendarCriticalPathEmptyTasks => '此路径中暂时没有任务';

  @override
  String get calendarCriticalPathNameEmptyError => '请输入名称';

  @override
  String get calendarCriticalPathNamePlaceholder => '关键路径名称';

  @override
  String get calendarCriticalPathNamePrompt => '名称';

  @override
  String get calendarCriticalPathTaskOrderTitle => '排序任务';

  @override
  String get calendarCriticalPathsAll => '所有路径';

  @override
  String get calendarCriticalPathsEmpty => '还没有关键路径';

  @override
  String get calendarCriticalPathsNew => '新建关键路径';

  @override
  String get calendarCriticalPathsTitle => '关键路径';

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return '删除“$title”？';
  }

  @override
  String get calendarErrorTitleEmptyFriendly => '标题不能为空';

  @override
  String get calendarExportFormatIcsSubtitle => '用于日历客户端';

  @override
  String get calendarExportFormatIcsTitle => '导出 .ics';

  @override
  String get calendarExportFormatJsonSubtitle => '用于备份或脚本';

  @override
  String get calendarExportFormatJsonTitle => '导出 JSON';

  @override
  String calendarRemovePathConfirm(Object name) {
    return '将此任务从“$name”中移除？';
  }

  @override
  String get calendarSandboxHint => '先在此规划任务，再分配到路径。';

  @override
  String get chatAlertHide => '隐藏';

  @override
  String get chatAlertIgnore => '忽略';

  @override
  String get chatAttachmentTapToLoad => '点击加载';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return '已添加 $recipient';
  }

  @override
  String get chatMessageAddRecipients => '添加收件人';

  @override
  String get chatMessageCreateChat => '创建聊天';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return '无法创建聊天：$reason';
  }

  @override
  String get chatMessageInfoDevice => '设备';

  @override
  String get chatMessageInfoError => '错误';

  @override
  String get chatMessageInfoProtocol => '协议';

  @override
  String get chatMessageInfoTimestamp => '时间戳';

  @override
  String get chatMessageOpenChat => '打开聊天';

  @override
  String get chatMessageStatusDisplayed => '已读';

  @override
  String get chatMessageStatusReceived => '已接收';

  @override
  String get chatMessageStatusSent => '已发送';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String emailDemoAccountLabel(Object account) {
    return 'Account: $account';
  }

  @override
  String get emailDemoDefaultMessage => 'Hello from Axichat';

  @override
  String get emailDemoDisplayNameSelf => 'Self';

  @override
  String get emailDemoErrorMissingPassphrase => 'Missing database passphrase.';

  @override
  String get emailDemoErrorMissingPrefix => 'Missing database prefix.';

  @override
  String get emailDemoErrorMissingProfile =>
      'No primary profile found. Log in first.';

  @override
  String get emailDemoMessageLabel => 'Demo message';

  @override
  String get emailDemoProvisionButton => 'Provision Email';

  @override
  String get emailDemoSendButton => 'Send Demo Message';

  @override
  String get emailDemoStatusIdle => 'Idle';

  @override
  String emailDemoStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get emailDemoStatusLoginToProvision => 'Log in to provision email.';

  @override
  String get emailDemoStatusNotProvisioned => 'Not provisioned';

  @override
  String emailDemoStatusProvisionFailed(Object error) {
    return 'Provisioning failed: $error';
  }

  @override
  String get emailDemoStatusProvisionFirst => 'Provision an account first.';

  @override
  String emailDemoStatusProvisioned(Object address) {
    return 'Provisioned $address';
  }

  @override
  String get emailDemoStatusProvisioning => 'Provisioning email account…';

  @override
  String get emailDemoStatusReady => 'Ready';

  @override
  String emailDemoStatusSendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get emailDemoStatusSending => 'Sending demo message…';

  @override
  String emailDemoStatusSent(Object id) {
    return 'Sent demo message (id=$id)';
  }

  @override
  String get emailDemoTitle => 'Email Transport Demo';

  @override
  String get linkedEmailAccountsTitle => 'Email accounts';

  @override
  String get linkedEmailAccountsDescription =>
      'Link existing inboxes and send from multiple addresses.';

  @override
  String get linkedEmailAccountsDefaultHint =>
      'New chats send from your default address unless you switch it per chat.';

  @override
  String linkedEmailAccountsLimitHint(Object limit) {
    return 'Up to $limit extra accounts.';
  }

  @override
  String get linkedEmailAccountsLinkAction => 'Link account';

  @override
  String get linkedEmailAccountsUnsupportedHint =>
      'This device supports one email account at a time.';

  @override
  String get linkedEmailAccountsEmptyTitle => 'No linked accounts yet';

  @override
  String get linkedEmailAccountsEmptyDescription =>
      'Add an existing inbox to sync mail and send from it.';

  @override
  String get linkedEmailAccountsLoadFailure => 'Unable to load email accounts.';

  @override
  String get linkedEmailAccountsMakeDefaultAction => 'Make default';

  @override
  String get linkedEmailAccountsUpdatePasswordAction => 'Update password';

  @override
  String get linkedEmailAccountsDefaultBadge => 'Default';

  @override
  String get linkedEmailAccountsRemoveTitle => 'Remove linked account?';

  @override
  String get linkedEmailAccountsRemoveDescription =>
      'You can re-link later. Existing messages stay.';

  @override
  String get linkedEmailAccountsUpdateTitle => 'Update email password';

  @override
  String get linkedEmailAccountsAccountLabel => 'Account';

  @override
  String get linkedEmailAccountsSheetTitle => 'Link an email account';

  @override
  String get linkedEmailAccountsSheetSubtitle =>
      'Use an app password if your provider requires it.';

  @override
  String get linkedEmailAccountsAddressPlaceholder => 'name@domain.com';

  @override
  String get linkedEmailAccountsAddressRequired => 'Enter an email address.';

  @override
  String get linkedEmailAccountsAddressInvalid =>
      'Enter a valid email address.';

  @override
  String get linkedEmailAccountsPasswordPlaceholder => 'Enter app password';

  @override
  String get linkedEmailAccountsPasswordLabel => 'App password';

  @override
  String get linkedEmailAccountsSetDefaultLabel =>
      'Set as default send address';

  @override
  String get linkedEmailAccountsSetDefaultDescription =>
      'New chats send from this address by default.';

  @override
  String linkedEmailAccountsLimitReached(Object limit) {
    return 'You can link up to $limit extra accounts.';
  }

  @override
  String get linkedEmailAccountsUnsupportedError =>
      'Multiple accounts are not supported on this device.';

  @override
  String get linkedEmailAccountsLinkFailure => 'Unable to link account.';

  @override
  String get linkedEmailAccountsUnlinkFailure => 'Unable to remove account.';

  @override
  String get linkedEmailAccountsDefaultFailure =>
      'Unable to update default address.';

  @override
  String get linkedEmailAccountsUpdateFailure => 'Unable to update password.';

  @override
  String get verificationAddLabelPlaceholder => 'Add label';

  @override
  String get verificationCurrentDevice => 'Current device';

  @override
  String verificationDeviceIdLabel(Object id) {
    return 'ID: $id';
  }

  @override
  String get verificationNotTrusted => 'Not trusted';

  @override
  String get verificationRegenerateDevice => 'Regenerate device';

  @override
  String get verificationRegenerateWarning =>
      'Only do this if you are an expert.';

  @override
  String get verificationTrustBlind => 'Blind trust';

  @override
  String get verificationTrustNone => 'No trust';

  @override
  String get verificationTrustVerified => 'Verified';

  @override
  String get verificationTrusted => 'Trusted';

  @override
  String get avatarSavedMessage => 'Avatar saved.';

  @override
  String get avatarCropTitle => 'Crop & focus';

  @override
  String get avatarCropDescription =>
      'Drag or resize the square to set your crop. Reset to center and follow the circle to match the saved avatar.';

  @override
  String get avatarCropPlaceholder =>
      'Add a photo or pick a default avatar to adjust the framing.';

  @override
  String avatarCropSizeLabel(Object pixels) {
    return '$pixels px crop';
  }

  @override
  String get avatarCropSavedSize => 'Saved at 256×256 • < 64 KB';

  @override
  String get avatarBackgroundTitle => 'Background color';

  @override
  String get avatarBackgroundDescription =>
      'Use the wheel or presets to tint transparent avatars before saving.';

  @override
  String get avatarBackgroundWheelTitle => 'Wheel & hex';

  @override
  String get avatarBackgroundWheelDescription =>
      'Drag the wheel or enter a hex value.';

  @override
  String get avatarBackgroundTransparent => 'Transparent';

  @override
  String get avatarBackgroundPreview => 'Preview saved circle tint.';

  @override
  String get avatarDefaultsTitle => 'Default avatars';

  @override
  String get avatarCategoryAbstract => 'Abstract';

  @override
  String get avatarCategoryStem => 'STEM';

  @override
  String get avatarCategorySports => 'Sports';

  @override
  String get avatarCategoryMusic => 'Music';

  @override
  String get avatarCategoryMisc => 'Hobbies & Games';

  @override
  String avatarTemplateAbstract(Object index) {
    return 'Abstract $index';
  }

  @override
  String get avatarTemplateAtom => 'Atom';

  @override
  String get avatarTemplateBeaker => 'Beaker';

  @override
  String get avatarTemplateCompass => 'Compass';

  @override
  String get avatarTemplateCpu => 'CPU';

  @override
  String get avatarTemplateGear => 'Gear';

  @override
  String get avatarTemplateGlobe => 'Globe';

  @override
  String get avatarTemplateLaptop => 'Laptop';

  @override
  String get avatarTemplateMicroscope => 'Microscope';

  @override
  String get avatarTemplateRobot => 'Robot';

  @override
  String get avatarTemplateStethoscope => 'Stethoscope';

  @override
  String get avatarTemplateTelescope => 'Telescope';

  @override
  String get avatarTemplateArchery => 'Archery';

  @override
  String get avatarTemplateBaseball => 'Baseball';

  @override
  String get avatarTemplateBasketball => 'Basketball';

  @override
  String get avatarTemplateBoxing => 'Boxing';

  @override
  String get avatarTemplateCycling => 'Cycling';

  @override
  String get avatarTemplateDarts => 'Darts';

  @override
  String get avatarTemplateFootball => 'Football';

  @override
  String get avatarTemplateGolf => 'Golf';

  @override
  String get avatarTemplatePingPong => 'Ping Pong';

  @override
  String get avatarTemplateSkiing => 'Skiing';

  @override
  String get avatarTemplateSoccer => 'Soccer';

  @override
  String get avatarTemplateTennis => 'Tennis';

  @override
  String get avatarTemplateVolleyball => 'Volleyball';

  @override
  String get avatarTemplateDrums => 'Drums';

  @override
  String get avatarTemplateElectricGuitar => 'Electric Guitar';

  @override
  String get avatarTemplateGuitar => 'Guitar';

  @override
  String get avatarTemplateMicrophone => 'Microphone';

  @override
  String get avatarTemplatePiano => 'Piano';

  @override
  String get avatarTemplateSaxophone => 'Saxophone';

  @override
  String get avatarTemplateViolin => 'Violin';

  @override
  String get avatarTemplateCards => 'Cards';

  @override
  String get avatarTemplateChess => 'Chess';

  @override
  String get avatarTemplateChessAlt => 'Chess Alt';

  @override
  String get avatarTemplateDice => 'Dice';

  @override
  String get avatarTemplateDiceAlt => 'Dice Alt';

  @override
  String get avatarTemplateEsports => 'Esports';

  @override
  String get avatarTemplateSword => 'Sword';

  @override
  String get avatarTemplateVideoGames => 'Video Games';

  @override
  String get avatarTemplateVideoGamesAlt => 'Video Games Alt';

  @override
  String get commonDone => '完成';

  @override
  String get commonRename => '重命名';

  @override
  String get calendarHour => '小时';

  @override
  String get calendarMinute => '分钟';

  @override
  String get calendarPasteTaskHere => '在此粘贴任务';

  @override
  String get calendarQuickAddTask => '快速添加任务';

  @override
  String get calendarSplitTaskAt => '拆分任务于';

  @override
  String get calendarAddDayEvent => '添加日程事件';

  @override
  String get calendarZoomOut => '缩小 (Ctrl/Cmd + -)';

  @override
  String get calendarZoomIn => '放大 (Ctrl/Cmd + +)';

  @override
  String get calendarChecklistItem => '清单项目';

  @override
  String get calendarRemoveItem => '移除项目';

  @override
  String get calendarAddChecklistItem => '添加清单项目';

  @override
  String get calendarRepeatTimes => '重复次数';

  @override
  String get calendarDayEventHint => '生日、节日或备注';

  @override
  String get calendarOptionalDetails => '可选详情';

  @override
  String get calendarDates => '日期';

  @override
  String get calendarTaskTitleHint => '任务标题';

  @override
  String get calendarDescriptionOptionalHint => '描述（可选）';

  @override
  String get calendarLocationOptionalHint => '地点（可选）';

  @override
  String get calendarCloseTooltip => '关闭';

  @override
  String get calendarAddTaskInputHint => '添加任务...（例如「明天下午3点开会」）';

  @override
  String get calendarBranch => '分支';

  @override
  String get calendarPickDifferentTask => '为此时段选择其他任务';

  @override
  String get calendarSyncRequest => '请求';

  @override
  String get calendarSyncPush => '推送';

  @override
  String get calendarImportant => '重要';

  @override
  String get calendarUrgent => '紧急';

  @override
  String get calendarClearSchedule => '清除日程';

  @override
  String get calendarEditTaskTooltip => '编辑任务';

  @override
  String get calendarDeleteTaskTooltip => '删除任务';

  @override
  String get calendarBackToChats => '返回聊天';

  @override
  String get calendarBackToLogin => '返回登录';

  @override
  String get calendarRemindersSection => '提醒';

  @override
  String get settingsAutoLoadEmailImages => '自动加载邮件图片';

  @override
  String get settingsAutoLoadEmailImagesDescription => '可能会向发件人泄露您的IP地址';

  @override
  String get settingsAutoDownloadImages => 'Auto-download images';

  @override
  String get settingsAutoDownloadImagesDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadVideos => 'Auto-download videos';

  @override
  String get settingsAutoDownloadVideosDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadDocuments => 'Auto-download documents';

  @override
  String get settingsAutoDownloadDocumentsDescription =>
      'Only for trusted chats.';

  @override
  String get settingsAutoDownloadArchives => 'Auto-download archives';

  @override
  String get settingsAutoDownloadArchivesDescription =>
      'Only for trusted chats.';

  @override
  String get chatChooseTextToAdd => '选择要添加的文本';
}

/// The translations for Chinese, as used in Hong Kong (`zh_HK`).
class AppLocalizationsZhHk extends AppLocalizationsZh {
  AppLocalizationsZhHk() : super('zh_HK');

  @override
  String get appTitle => 'axichat';

  @override
  String get homeTabChats => '聊天';

  @override
  String get homeTabDrafts => '草稿';

  @override
  String get homeTabSpam => '垃圾郵件';

  @override
  String get homeTabBlocked => '已封鎖';

  @override
  String get homeNoModules => '沒有可用模組';

  @override
  String get homeRailShowMenu => '顯示選單';

  @override
  String get homeRailHideMenu => '隱藏選單';

  @override
  String get homeRailCalendar => '日曆';

  @override
  String get homeSearchPlaceholderTabs => '搜尋分頁';

  @override
  String homeSearchPlaceholderForTab(Object tab) {
    return '搜尋$tab';
  }

  @override
  String homeSearchFilterLabel(Object filter) {
    return '篩選：$filter';
  }

  @override
  String get blocklistFilterAll => '全部已封鎖';

  @override
  String get draftsFilterAll => '所有草稿';

  @override
  String get draftsFilterAttachments => '含附件';

  @override
  String get chatsFilterAll => '所有聊天';

  @override
  String get chatsFilterContacts => '聯絡人';

  @override
  String get chatsFilterNonContacts => '非聯絡人';

  @override
  String get chatsFilterXmppOnly => '只限 XMPP';

  @override
  String get chatsFilterEmailOnly => '只限電郵';

  @override
  String get chatsFilterHidden => '已隱藏';

  @override
  String get spamFilterAll => '所有垃圾郵件';

  @override
  String get spamFilterEmail => '電郵';

  @override
  String get spamFilterXmpp => 'XMPP';

  @override
  String get chatFilterDirectOnly => '只限直接';

  @override
  String get chatFilterAllWithContact => '全部（含聯絡人）';

  @override
  String get chatSearchMessages => '搜尋訊息';

  @override
  String get chatSearchSortNewestFirst => '最新優先';

  @override
  String get chatSearchSortOldestFirst => '最早優先';

  @override
  String get chatSearchAnySubject => '任何主題';

  @override
  String get chatSearchExcludeSubject => '排除主題';

  @override
  String get chatSearchFailed => '搜尋失敗';

  @override
  String get chatSearchInProgress => '正在搜尋…';

  @override
  String get chatSearchEmptyPrompt => '配對結果會顯示在下方對話中。';

  @override
  String get chatSearchNoMatches => '沒有配對。請調整篩選或再試其他關鍵字。';

  @override
  String chatSearchMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '顯示 # 個配對結果。',
      one: '顯示 # 個配對結果。',
    );
    return '$_temp0';
  }

  @override
  String filterTooltip(Object label) {
    return '篩選 • $label';
  }

  @override
  String get chatSearchClose => '關閉搜尋';

  @override
  String get commonSearch => '搜尋';

  @override
  String get commonClear => '清除';

  @override
  String get commonCancel => '取消';

  @override
  String get spamEmpty => '暫時沒有垃圾郵件';

  @override
  String get spamMoveToInbox => '移至收件箱';

  @override
  String get spamMoveToastTitle => '已移動';

  @override
  String spamMoveToastMessage(Object chatTitle) {
    return '已將 $chatTitle 移回收件箱。';
  }

  @override
  String get chatSpamUpdateFailed => '更新垃圾郵件狀態失敗。';

  @override
  String chatSpamSent(Object chatTitle) {
    return '已將 $chatTitle 標記為垃圾郵件。';
  }

  @override
  String chatSpamRestored(Object chatTitle) {
    return '已將 $chatTitle 移回收件箱。';
  }

  @override
  String get chatSpamReportedTitle => '已舉報';

  @override
  String get chatSpamRestoredTitle => '已還原';

  @override
  String get chatMembersLoading => '正在載入成員';

  @override
  String get chatMembersLoadingEllipsis => '正在載入成員…';

  @override
  String get chatAttachmentConfirmTitle => '載入附件？';

  @override
  String chatAttachmentConfirmMessage(Object sender) {
    return '請只載入信任聯絡人的附件。\n\n$sender 尚未在你的聯絡人中。是否繼續？';
  }

  @override
  String get chatAttachmentConfirmButton => '載入';

  @override
  String get attachmentGalleryRosterTrustLabel => '自動下載來自此用戶的檔案';

  @override
  String get attachmentGalleryRosterTrustHint => '你可以稍後在聊天設定中關閉。';

  @override
  String get attachmentGalleryChatTrustLabel => '一律允許此聊天中的附件';

  @override
  String get attachmentGalleryChatTrustHint => '你可以稍後在聊天設定中關閉。';

  @override
  String get attachmentGalleryRosterErrorTitle => '無法加入聯絡人';

  @override
  String get attachmentGalleryRosterErrorMessage => '已下載此附件一次，但自動下載仍被停用。';

  @override
  String get attachmentGalleryErrorMessage => '無法載入附件。';

  @override
  String get attachmentGalleryAllLabel => '全部';

  @override
  String get attachmentGalleryImagesLabel => '圖片';

  @override
  String get attachmentGalleryVideosLabel => '影片';

  @override
  String get attachmentGalleryFilesLabel => '檔案';

  @override
  String get attachmentGallerySentLabel => '已傳送';

  @override
  String get attachmentGalleryReceivedLabel => '已接收';

  @override
  String get attachmentGallerySortNameAscLabel => '名稱 A-Z';

  @override
  String get attachmentGallerySortNameDescLabel => '名稱 Z-A';

  @override
  String get attachmentGallerySortSizeAscLabel => '大小由小到大';

  @override
  String get attachmentGallerySortSizeDescLabel => '大小由大到小';

  @override
  String get chatOpenLinkTitle => '開啟外部連結？';

  @override
  String chatOpenLinkMessage(Object url, Object host) {
    return '你將要開啟：\n$url\n\n只有在信任該網站時才按確定（主機：$host）。';
  }

  @override
  String chatOpenLinkWarningMessage(Object url, Object host) {
    return '你將要開啟：\n$url\n\n該連結包含異常或不可見字元。請仔細核對地址（主機：$host）。';
  }

  @override
  String get chatOpenLinkConfirm => '開啟連結';

  @override
  String chatInvalidLink(Object url) {
    return '無效的連結：$url';
  }

  @override
  String chatUnableToOpenHost(Object host) {
    return '無法開啟 $host';
  }

  @override
  String get chatSaveAsDraft => '儲存為草稿';

  @override
  String get chatDraftUnavailable => '暫時無法使用草稿。';

  @override
  String get chatDraftMissingContent => '請先加入訊息、主題或附件再儲存。';

  @override
  String get chatDraftSaved => '已儲存到草稿。';

  @override
  String get chatDraftSaveFailed => '無法儲存草稿，請再試一次。';

  @override
  String get chatAttachmentInaccessible => '所選檔案無法存取。';

  @override
  String get chatAttachmentFailed => '無法加入附件。';

  @override
  String get chatAttachmentView => '檢視';

  @override
  String get chatAttachmentRetry => '重新上傳';

  @override
  String get chatAttachmentRemove => '移除附件';

  @override
  String get commonClose => '關閉';

  @override
  String get toastWhoopsTitle => '哎呀';

  @override
  String get toastHeadsUpTitle => '提醒';

  @override
  String get toastAllSetTitle => '完成';

  @override
  String get chatRoomMembers => '聊天室成員';

  @override
  String get chatCloseSettings => '關閉設定';

  @override
  String get chatSettings => '聊天設定';

  @override
  String get chatEmptySearch => '沒有配對';

  @override
  String get chatEmptyMessages => '沒有訊息';

  @override
  String get chatComposerEmailHint => '傳送電郵訊息';

  @override
  String get chatComposerMessageHint => '傳送訊息';

  @override
  String get chatReadOnly => '唯讀';

  @override
  String get chatUnarchivePrompt => '取消封存後才可傳送新訊息。';

  @override
  String get chatEmojiPicker => '表情選擇器';

  @override
  String get chatShowingDirectOnly => '僅顯示直接訊息';

  @override
  String get chatShowingAll => '顯示全部';

  @override
  String get chatMuteNotifications => '靜音通知';

  @override
  String get chatEnableNotifications => '啟用通知';

  @override
  String get chatMoveToInbox => '移至收件箱';

  @override
  String get chatReportSpam => '回報垃圾郵件';

  @override
  String get chatSignatureToggleLabel => '為電郵加入分享權杖頁腳';

  @override
  String get chatSignatureHintEnabled => '有助保持多收件人的電郵串。';

  @override
  String get chatSignatureHintDisabled => '已全域停用；回覆可能無法串接。';

  @override
  String get chatSignatureHintWarning => '停用可能會影響串接和附件分組。';

  @override
  String get chatInviteRevoked => '邀請已撤銷';

  @override
  String get chatInvite => '邀請';

  @override
  String get chatReactionsNone => '暫無表情回應';

  @override
  String get chatReactionsPrompt => '點一下表情以新增或移除你的回應';

  @override
  String get chatReactionsPick => '選擇一個表情來回應';

  @override
  String get chatActionReply => '回覆';

  @override
  String get chatActionForward => '轉寄';

  @override
  String get chatActionResend => '重新傳送';

  @override
  String get chatActionEdit => '編輯';

  @override
  String get chatActionRevoke => '撤銷';

  @override
  String get chatActionCopy => '複製';

  @override
  String get chatActionShare => '分享';

  @override
  String get chatActionAddToCalendar => '加入行事曆';

  @override
  String get chatCalendarTaskCopyActionLabel => '複製到行事曆';

  @override
  String get chatCalendarTaskImportConfirmTitle => '加入行事曆？';

  @override
  String get chatCalendarTaskImportConfirmMessage => '此任務來自聊天。加入你的行事曆以便管理或編輯。';

  @override
  String get chatCalendarTaskImportConfirmLabel => '加入行事曆';

  @override
  String get chatCalendarTaskImportCancelLabel => '暫不';

  @override
  String get chatCalendarTaskCopyUnavailableMessage => '行事曆無法使用。';

  @override
  String get chatCalendarTaskCopyAlreadyAddedMessage => '任務已加入。';

  @override
  String get chatCalendarTaskCopySuccessMessage => '任務已複製。';

  @override
  String get chatActionDetails => '詳細資料';

  @override
  String get chatActionSelect => '選取';

  @override
  String get chatActionReact => '回應';

  @override
  String get chatContactRenameAction => '重新命名';

  @override
  String get chatContactRenameTooltip => '重新命名聯絡人';

  @override
  String get chatContactRenameTitle => '重新命名聯絡人';

  @override
  String get chatContactRenameDescription => '選擇此聯絡人在 Axichat 的顯示方式。';

  @override
  String get chatContactRenamePlaceholder => '顯示名稱';

  @override
  String get chatContactRenameReset => '重設為預設';

  @override
  String get chatContactRenameSave => '儲存';

  @override
  String get chatContactRenameSuccess => '顯示名稱已更新';

  @override
  String get chatContactRenameFailure => '無法重新命名聯絡人';

  @override
  String get chatComposerSemantics => '訊息輸入框';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get draftErrorTitle => '糟了';

  @override
  String get draftNoRecipients => '沒有收件者';

  @override
  String get draftSubjectSemantics => '電郵主旨';

  @override
  String get draftSubjectHintOptional => '主旨（可選）';

  @override
  String get draftMessageSemantics => '訊息內容';

  @override
  String get draftMessageHint => '訊息';

  @override
  String get draftSendingStatus => '正在傳送...';

  @override
  String get draftSendingEllipsis => '正在傳送…';

  @override
  String get draftSend => '傳送草稿';

  @override
  String get draftDiscard => '捨棄';

  @override
  String get draftSave => '儲存草稿';

  @override
  String get draftAttachmentInaccessible => '所選檔案無法存取。';

  @override
  String get draftAttachmentFailed => '無法附加檔案。';

  @override
  String get draftDiscarded => '草稿已捨棄。';

  @override
  String get draftSendFailed => '無法傳送草稿。';

  @override
  String get draftSent => '已傳送';

  @override
  String draftLimitWarning(int limit, int count) {
    return '草稿同步最多保留 $limit 個草稿。你已有 $count 個。';
  }

  @override
  String get draftValidationNoContent => '請新增主旨、訊息或附件';

  @override
  String draftFileMissing(Object path) {
    return '檔案在 $path 已不存在。';
  }

  @override
  String get draftAttachmentPreview => '預覽';

  @override
  String get draftRemoveAttachment => '移除附件';

  @override
  String get draftNoAttachments => '尚未有附件';

  @override
  String get draftAttachmentsLabel => '附件';

  @override
  String get draftAddAttachment => '新增附件';

  @override
  String draftTaskDue(Object date) {
    return '到期 $date';
  }

  @override
  String get draftTaskNoSchedule => '未排程';

  @override
  String get draftTaskUntitled => '未命名的任務';

  @override
  String get chatBack => '返回';

  @override
  String get chatErrorLabel => '錯誤！';

  @override
  String get chatSenderYou => '你';

  @override
  String get chatInviteAlreadyInRoom => '已在此聊天室。';

  @override
  String get chatInviteWrongAccount => '此邀請不適用於這個帳號。';

  @override
  String get chatShareNoText => '此訊息沒有可分享的文字。';

  @override
  String get chatShareFallbackSubject => 'Axichat 訊息';

  @override
  String chatShareSubjectPrefix(Object chatTitle) {
    return '來自 $chatTitle';
  }

  @override
  String get chatCalendarNoText => '此訊息沒有可加入行事曆的文字。';

  @override
  String get chatCalendarUnavailable => '行事曆目前不可用。';

  @override
  String get chatCopyNoText => '已選訊息沒有可複製的文字。';

  @override
  String get chatShareSelectedNoText => '已選訊息沒有可分享的文字。';

  @override
  String get chatForwardInviteForbidden => '無法轉寄邀請。';

  @override
  String get chatAddToCalendarNoText => '已選訊息沒有可加入行事曆的文字。';

  @override
  String get chatForwardDialogTitle => '轉寄到...';

  @override
  String get chatForwardEmailWarningTitle => 'Forward email?';

  @override
  String get chatForwardEmailWarningMessage =>
      'Forwarding email can include original headers and external image links. Choose how to send.';

  @override
  String get chatForwardEmailOptionSafe => 'Forward as new message';

  @override
  String get chatForwardEmailOptionOriginal => 'Forward original';

  @override
  String get chatComposerAttachmentWarning => '大型附件會分別傳送給每位收件者，可能需要更長時間。';

  @override
  String chatFanOutRecipientLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '收件者',
      one: '收件者',
    );
    return '$_temp0';
  }

  @override
  String chatFanOutFailureWithSubject(
      Object subject, int count, Object recipientLabel) {
    return '主題「$subject」傳送給$count$recipientLabel失敗。';
  }

  @override
  String chatFanOutFailure(int count, Object recipientLabel) {
    return '傳送給$count$recipientLabel失敗。';
  }

  @override
  String get chatFanOutRetry => '重試';

  @override
  String get chatSubjectSemantics => '電子郵件主旨';

  @override
  String get chatSubjectHint => '主旨';

  @override
  String get chatAttachmentTooltip => '附件';

  @override
  String get chatPinnedMessagesTooltip => 'Pinned messages';

  @override
  String get chatPinnedMessagesTitle => 'Pinned messages';

  @override
  String get chatPinMessage => 'Pin message';

  @override
  String get chatUnpinMessage => 'Unpin message';

  @override
  String get chatPinnedEmptyState => 'No pinned messages yet.';

  @override
  String get chatPinnedMissingMessage => 'Pinned message is unavailable.';

  @override
  String get chatSendMessageTooltip => '傳送訊息';

  @override
  String get chatBlockAction => '封鎖';

  @override
  String get chatReactionMore => '更多';

  @override
  String get chatQuotedNoContent => '（無內容）';

  @override
  String get chatReplyingTo => '回覆中...';

  @override
  String get chatCancelReply => '取消回覆';

  @override
  String get chatMessageRetracted => '（已撤回）';

  @override
  String get chatMessageEdited => '（已編輯）';

  @override
  String get chatGuestAttachmentsDisabled => '預覽中已停用附件。';

  @override
  String get chatGuestSubtitle => '訪客預覽 • 本機儲存';

  @override
  String recipientsOverflowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count 個更多',
      one: '+1 個更多',
    );
    return '$_temp0';
  }

  @override
  String get recipientsCollapse => '收起';

  @override
  String recipientsSemantics(int count, Object state) {
    return '收件者 $count，$state';
  }

  @override
  String get recipientsStateCollapsed => '已收起';

  @override
  String get recipientsStateExpanded => '已展開';

  @override
  String get recipientsHintExpand => '點擊展開';

  @override
  String get recipientsHintCollapse => '點擊收起';

  @override
  String get recipientsHeaderTitle => '傳送至...';

  @override
  String get recipientsFallbackLabel => '收件者';

  @override
  String get recipientsAddHint => '新增...';

  @override
  String get chatGuestScriptWelcome => '歡迎使用 Axichat——在同一個地方處理聊天、電子郵件與行事曆。';

  @override
  String get chatGuestScriptExternalQuestion => '看起來很清爽。可以傳訊給沒有用 Axichat 的人嗎？';

  @override
  String get chatGuestScriptExternalAnswer =>
      '可以——把聊天格式的郵件發送到 Gmail、Outlook、Tuta 等。如果雙方都用 Axichat，還有群組聊天、表情回應、送達回條等功能。';

  @override
  String get chatGuestScriptOfflineQuestion => '離線或訪客模式可以用嗎？';

  @override
  String get chatGuestScriptOfflineAnswer =>
      '可以——內建離線功能，行事曆在訪客模式下即使沒有帳號或網路也能使用。';

  @override
  String get chatGuestScriptKeepUpQuestion => '它如何幫助我掌握所有事情？';

  @override
  String get chatGuestScriptKeepUpAnswer =>
      '我們的行事曆支援自然語言排程、艾森豪矩陣、拖放與提醒，讓你專注重要事項。';

  @override
  String calendarParserUnavailable(Object errorType) {
    return '解析器不可用（$errorType）';
  }

  @override
  String get calendarAddTaskTitle => '新增任務';

  @override
  String get calendarTaskNameRequired => '任務名稱 *';

  @override
  String get calendarTaskNameHint => '任務名稱';

  @override
  String get calendarDescriptionHint => '描述（可選）';

  @override
  String get calendarLocationHint => '位置（可選）';

  @override
  String get calendarScheduleLabel => '安排';

  @override
  String get calendarDeadlineLabel => '截止日期';

  @override
  String get calendarRepeatLabel => '重複';

  @override
  String get calendarCancel => '取消';

  @override
  String get calendarAddTaskAction => '新增任務';

  @override
  String get calendarSelectionMode => '選取模式';

  @override
  String get calendarExit => '退出';

  @override
  String calendarTasksSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選 # 個任務',
      one: '已選 # 個任務',
    );
    return '$_temp0';
  }

  @override
  String get calendarActions => '操作';

  @override
  String get calendarSetPriority => '設定優先級';

  @override
  String get calendarClearSelection => '清除選取';

  @override
  String get calendarExportSelected => '匯出選取';

  @override
  String get calendarDeleteSelected => '刪除選取';

  @override
  String get calendarBatchEdit => '批次編輯';

  @override
  String get calendarBatchTitle => '標題';

  @override
  String get calendarBatchTitleHint => '替已選任務設定標題';

  @override
  String get calendarBatchDescription => '描述';

  @override
  String get calendarBatchDescriptionHint => '設定描述（留空則清除）';

  @override
  String get calendarBatchLocation => '位置';

  @override
  String get calendarBatchLocationHint => '設定位置（留空則清除）';

  @override
  String get calendarApplyChanges => '套用變更';

  @override
  String get calendarAdjustTime => '調整時間';

  @override
  String get calendarSelectionRequired => '套用變更前請先選擇任務。';

  @override
  String get calendarSelectionNone => '請先選擇要匯出的任務。';

  @override
  String get calendarSelectionChangesApplied => '變更已套用至選取的任務。';

  @override
  String get calendarSelectionNoPending => '沒有待套用的變更。';

  @override
  String get calendarSelectionTitleBlank => '標題不能為空。';

  @override
  String get calendarExportReady => '匯出可供分享。';

  @override
  String calendarExportFailed(Object error) {
    return '匯出所選任務失敗：$error';
  }

  @override
  String get commonBack => '返回';

  @override
  String get composeTitle => '撰寫';

  @override
  String get draftComposeMessage => '撰寫訊息';

  @override
  String get draftCompose => '撰寫';

  @override
  String get draftNewMessage => '新訊息';

  @override
  String get draftRestore => '還原';

  @override
  String get draftMinimize => '最小化';

  @override
  String get draftExpand => '展開';

  @override
  String get draftExitFullscreen => '退出全螢幕';

  @override
  String get draftCloseComposer => '關閉編輯器';

  @override
  String get draftsEmpty => '尚無草稿';

  @override
  String get draftsDeleteConfirm => '刪除草稿？';

  @override
  String get draftNoSubject => '（無主題）';

  @override
  String draftRecipientCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位收件人',
      one: '$count 位收件人',
    );
    return '$_temp0';
  }

  @override
  String get authCreatingAccount => '正在建立您的帳戶…';

  @override
  String get authSecuringLogin => '正在保護您的登入…';

  @override
  String get authLoggingIn => '正在登入…';

  @override
  String get authToggleSignup => '新用戶？註冊';

  @override
  String get authToggleLogin => '已有帳戶？登入';

  @override
  String get authGuestCalendarCta => '試用行事曆（訪客模式）';

  @override
  String get authLogin => '登入';

  @override
  String get authRememberMeLabel => '在此裝置上記住我';

  @override
  String get authSignUp => '註冊';

  @override
  String get authToggleSelected => '目前選擇';

  @override
  String authToggleSelectHint(Object label) {
    return '點擊以選擇 $label';
  }

  @override
  String get authUsername => '用戶名';

  @override
  String get authUsernameRequired => '請輸入用戶名';

  @override
  String get authUsernameRules => '4-20 個字母或數字，可包含「.」「_」「-」。';

  @override
  String get authUsernameCaseInsensitive => '不分大小寫';

  @override
  String get authPassword => '密碼';

  @override
  String get authPasswordConfirm => '確認密碼';

  @override
  String get authPasswordRequired => '請輸入密碼';

  @override
  String authPasswordMaxLength(Object max) {
    return '長度必須不超過 $max 個字元';
  }

  @override
  String get authPasswordsMismatch => '兩次密碼不一致';

  @override
  String get authPasswordPending => '正在檢查密碼安全性';

  @override
  String get authSignupPending => '正在註冊';

  @override
  String get authLoginPending => '正在登入';

  @override
  String get signupTitle => '註冊';

  @override
  String get signupStepUsername => '選擇用戶名';

  @override
  String get signupStepPassword => '建立密碼';

  @override
  String get signupStepCaptcha => '驗證驗證碼';

  @override
  String get signupStepSetup => '設定';

  @override
  String signupErrorPrefix(Object message) {
    return '錯誤：$message';
  }

  @override
  String get signupCaptchaUnavailable => '驗證碼無法使用';

  @override
  String get signupCaptchaChallenge => '驗證碼挑戰';

  @override
  String get signupCaptchaFailed => '驗證碼載入失敗。請重新整理重試。';

  @override
  String get signupCaptchaLoading => '正在載入驗證碼';

  @override
  String get signupCaptchaInstructions => '請輸入驗證碼圖片中的字元。';

  @override
  String get signupCaptchaReload => '重新載入驗證碼';

  @override
  String get signupCaptchaReloadHint => '看不清時取得新的驗證碼圖片。';

  @override
  String get signupCaptchaPlaceholder => '輸入上方文字';

  @override
  String get signupCaptchaValidation => '輸入圖片中的文字';

  @override
  String get signupContinue => '繼續';

  @override
  String get signupProgressLabel => '註冊進度';

  @override
  String signupProgressValue(
      Object current, Object currentLabel, Object percent, Object total) {
    return '第 $current/$total 步：$currentLabel。已完成 $percent%。';
  }

  @override
  String get signupProgressSection => '帳戶設定';

  @override
  String get signupPasswordStrength => '密碼強度';

  @override
  String get signupPasswordBreached => '此密碼出現在外洩的資料庫中。';

  @override
  String get signupStrengthNone => '無';

  @override
  String get signupStrengthWeak => '弱';

  @override
  String get signupStrengthMedium => '中';

  @override
  String get signupStrengthStronger => '較強';

  @override
  String get signupRiskAcknowledgement => '我了解風險';

  @override
  String get signupRiskError => '請勾選上方的核取方塊以繼續。';

  @override
  String get signupRiskAllowBreach => '即使此密碼出現在外洩中也允許使用。';

  @override
  String get signupRiskAllowWeak => '即使此密碼被視為弱也允許使用。';

  @override
  String get signupCaptchaErrorMessage => '無法載入驗證碼。\n請點擊重新整理再試一次。';

  @override
  String get signupAvatarRenderError => '無法渲染該頭像。';

  @override
  String get signupAvatarLoadError => '無法載入該頭像。';

  @override
  String get signupAvatarReadError => '無法讀取該圖片。';

  @override
  String get signupAvatarOpenError => '無法開啟該檔案。';

  @override
  String get signupAvatarInvalidImage => '該檔案不是有效的圖片。';

  @override
  String signupAvatarSizeError(Object kilobytes) {
    return '頭像必須小於 $kilobytes KB。';
  }

  @override
  String get signupAvatarProcessError => '無法處理該圖片。';

  @override
  String get signupAvatarEdit => '編輯頭像';

  @override
  String get signupAvatarUploadImage => '上載圖片';

  @override
  String get signupAvatarUpload => '上載';

  @override
  String get signupAvatarShuffle => '隨機預設頭像';

  @override
  String get signupAvatarMenuDescription => '我們會在建立 XMPP 帳戶後發布你的頭像。';

  @override
  String get avatarSaveAvatar => '儲存頭像';

  @override
  String get signupAvatarBackgroundColor => '背景顏色';

  @override
  String get signupAvatarDefaultsTitle => '預設頭像';

  @override
  String get signupAvatarCategoryAbstract => '抽象';

  @override
  String get signupAvatarCategoryScience => '科學';

  @override
  String get signupAvatarCategorySports => '運動';

  @override
  String get signupAvatarCategoryMusic => '音樂';

  @override
  String get notificationsRestartTitle => '重新啟動應用程式以啟用通知';

  @override
  String get notificationsRestartSubtitle => '必要權限已授予';

  @override
  String get notificationsMessageToggle => '訊息通知';

  @override
  String get notificationsRequiresRestart => '需要重新啟動';

  @override
  String get notificationsDialogTitle => '啟用訊息通知';

  @override
  String get notificationsDialogIgnore => '忽略';

  @override
  String get notificationsDialogContinue => '繼續';

  @override
  String get notificationsDialogDescription => '聊天隨時可以靜音。';

  @override
  String get calendarAdjustStartMinus => '開始 -15 分';

  @override
  String get calendarAdjustStartPlus => '開始 +15 分';

  @override
  String get calendarAdjustEndMinus => '結束 -15 分';

  @override
  String get calendarAdjustEndPlus => '結束 +15 分';

  @override
  String get calendarCopyToClipboardAction => '複製到剪貼簿';

  @override
  String calendarCopyLocation(Object location) {
    return '地點：$location';
  }

  @override
  String get calendarTaskCopied => '已複製任務';

  @override
  String get calendarTaskCopiedClipboard => '任務已複製到剪貼簿';

  @override
  String get calendarCopyTask => '複製任務';

  @override
  String get calendarDeleteTask => '刪除任務';

  @override
  String get calendarSelectionNoneShort => '未選擇任務。';

  @override
  String get calendarSelectionMixedRecurrence => '任務的重複設定不同。變更將套用到所有選取的任務。';

  @override
  String get calendarSelectionNoTasksHint => '未選擇任務。請在行事曆中使用「選取」來挑選要編輯的任務。';

  @override
  String get calendarSelectionRemove => '從選取中移除';

  @override
  String get calendarQuickTaskHint => '快速任務（例如：「下午2點在101室開會」）';

  @override
  String get calendarAdvancedHide => '隱藏進階選項';

  @override
  String get calendarAdvancedShow => '顯示進階選項';

  @override
  String get calendarUnscheduledTitle => '未排程的任務';

  @override
  String get calendarUnscheduledEmptyLabel => '目前沒有未排程的任務';

  @override
  String get calendarUnscheduledEmptyHint => '你新增的任務會顯示在這裡';

  @override
  String get calendarRemindersTitle => '提醒';

  @override
  String get calendarRemindersEmptyLabel => '尚未有提醒';

  @override
  String get calendarRemindersEmptyHint => '新增截止時間即可建立提醒';

  @override
  String get calendarNothingHere => '這裡還沒有內容';

  @override
  String get calendarTaskNotFound => '找不到任務';

  @override
  String get calendarDayEventsTitle => '當日事件';

  @override
  String get calendarDayEventsEmpty => '此日期沒有日程事件';

  @override
  String get calendarDayEventsAdd => '新增日程事件';

  @override
  String get accessibilityNewContactLabel => '聯絡地址';

  @override
  String get accessibilityNewContactHint => 'someone@example.com';

  @override
  String get accessibilityStartChat => '開始聊天';

  @override
  String get accessibilityStartChatHint => '提交此地址以開始對話。';

  @override
  String get accessibilityMessagesEmpty => '暫時沒有訊息';

  @override
  String get accessibilityMessageNoContent => '沒有訊息內容';

  @override
  String get accessibilityActionsTitle => '操作';

  @override
  String get accessibilityReadNewMessages => '閱讀新訊息';

  @override
  String get accessibilityUnreadSummaryDescription => '專注於有未讀訊息的對話';

  @override
  String get accessibilityStartNewChat => '開始新的聊天';

  @override
  String get accessibilityStartNewChatDescription => '選擇聯絡人或輸入地址';

  @override
  String get accessibilityInvitesTitle => '邀請';

  @override
  String get accessibilityPendingInvites => '待處理邀請';

  @override
  String get accessibilityAcceptInvite => '接受邀請';

  @override
  String get accessibilityInviteAccepted => '已接受邀請';

  @override
  String get accessibilityInviteDismissed => '已拒絕邀請';

  @override
  String get accessibilityInviteUpdateFailed => '無法更新邀請';

  @override
  String get accessibilityUnreadEmpty => '沒有未讀對話';

  @override
  String get accessibilityInvitesEmpty => '沒有待處理的邀請';

  @override
  String get accessibilityMessagesTitle => '訊息';

  @override
  String get accessibilityNoConversationSelected => '未選擇對話';

  @override
  String accessibilityMessagesWithContact(Object name) {
    return '$name 的訊息';
  }

  @override
  String accessibilityMessageLabel(
      Object sender, Object timestamp, Object body) {
    return '$sender 於 $timestamp：$body';
  }

  @override
  String get accessibilityMessageSent => '訊息已傳送。';

  @override
  String get accessibilityDiscardWarning => '再次按下 Escape 以捨棄訊息並關閉此步驟。';

  @override
  String get accessibilityDraftLoaded => '草稿已載入。按 Escape 離開或儲存以保留變更。';

  @override
  String accessibilityDraftLabel(Object id) {
    return '草稿 $id';
  }

  @override
  String accessibilityDraftLabelWithRecipients(Object recipients) {
    return '給 $recipients 的草稿';
  }

  @override
  String accessibilityDraftPreview(Object recipients, Object preview) {
    return '$recipients — $preview';
  }

  @override
  String accessibilityIncomingMessageStatus(Object sender, Object time) {
    return '來自 $sender 的新訊息，時間 $time';
  }

  @override
  String accessibilityAttachmentWithName(Object filename) {
    return '附件：$filename';
  }

  @override
  String get accessibilityAttachmentGeneric => '附件';

  @override
  String get accessibilityUploadAvailable => '可用的上傳';

  @override
  String get accessibilityUnknownContact => '未知聯絡人';

  @override
  String get accessibilityChooseContact => '選擇聯絡人';

  @override
  String get accessibilityUnreadConversations => '未讀對話';

  @override
  String get accessibilityStartNewAddress => '輸入新地址';

  @override
  String accessibilityConversationWith(Object name) {
    return '與 $name 的對話';
  }

  @override
  String get accessibilityConversationLabel => '對話';

  @override
  String get accessibilityDialogLabel => '無障礙操作對話框';

  @override
  String get accessibilityDialogHint =>
      '按 Tab 查看捷徑說明，在清單中使用方向鍵，按住 Shift 加方向鍵切換群組，或按 Escape 離開。';

  @override
  String get accessibilityNoActionsAvailable => '目前沒有可用的操作';

  @override
  String accessibilityBreadcrumbLabel(
      Object position, Object total, Object label) {
    return '第 $position/$total 步：$label。啟用以跳至此步驟。';
  }

  @override
  String get accessibilityShortcutOpenMenu => '開啟選單';

  @override
  String get accessibilityShortcutBack => '後退一步或關閉';

  @override
  String get accessibilityShortcutNextFocus => '下一個焦點目標';

  @override
  String get accessibilityShortcutPreviousFocus => '上一個焦點目標';

  @override
  String get accessibilityShortcutActivateItem => '啟用項目';

  @override
  String get accessibilityShortcutNextItem => '下一個項目';

  @override
  String get accessibilityShortcutPreviousItem => '上一個項目';

  @override
  String get accessibilityShortcutNextGroup => '下一個群組';

  @override
  String get accessibilityShortcutPreviousGroup => '上一個群組';

  @override
  String get accessibilityShortcutFirstItem => '第一個項目';

  @override
  String get accessibilityShortcutLastItem => '最後一個項目';

  @override
  String get accessibilityKeyboardShortcutsTitle => '鍵盤捷徑';

  @override
  String accessibilityKeyboardShortcutAnnouncement(Object description) {
    return '鍵盤捷徑：$description';
  }

  @override
  String get accessibilityTextFieldHint => '輸入文字。按 Tab 前進，或按 Escape 返回或關閉選單。';

  @override
  String get accessibilityComposerPlaceholder => '輸入訊息';

  @override
  String accessibilityRecipientLabel(Object name) {
    return '收件人 $name';
  }

  @override
  String get accessibilityRecipientRemoveHint => '按退格或刪除鍵移除';

  @override
  String get accessibilityMessageActionsLabel => '訊息操作';

  @override
  String get accessibilityMessageActionsHint => '儲存為草稿或傳送此訊息';

  @override
  String accessibilityMessagePosition(Object position, Object total) {
    return '第 $position 則訊息，共 $total 則';
  }

  @override
  String get accessibilityNoMessages => '沒有訊息';

  @override
  String accessibilityMessageMetadata(Object sender, Object timestamp) {
    return '來自 $sender 於 $timestamp';
  }

  @override
  String accessibilityMessageFrom(Object sender) {
    return '來自 $sender';
  }

  @override
  String get accessibilityMessageNavigationHint =>
      '使用方向鍵在訊息間移動。按住 Shift 加方向鍵切換群組。按 Escape 離開。';

  @override
  String accessibilitySectionSummary(Object section, Object count) {
    return '$section 區塊，包含 $count 項';
  }

  @override
  String accessibilityActionListLabel(Object count) {
    return '操作清單，共 $count 項';
  }

  @override
  String get accessibilityActionListHint =>
      '使用方向鍵移動，按住 Shift 加方向鍵切換群組，Home/End 跳轉，Enter 啟用，Escape 離開。';

  @override
  String accessibilityActionItemPosition(
      Object position, Object total, Object section) {
    return '$section 中的第 $position 個項目，共 $total 個';
  }

  @override
  String get accessibilityActionReadOnlyHint => '使用方向鍵瀏覽清單';

  @override
  String get accessibilityActionActivateHint => '按 Enter 啟用';

  @override
  String get accessibilityDismissHighlight => '關閉提示';

  @override
  String get accessibilityNeedsAttention => '需要注意';

  @override
  String get profileTitle => '個人資料';

  @override
  String get profileJidDescription =>
      '這是你的 Jabber ID，由使用者名稱與網域組成，是你在 XMPP 網路上的唯一地址。';

  @override
  String get profileResourceDescription =>
      '這是你的 XMPP 資源。每台裝置都有自己的資源，因此手機與桌機的在線狀態可能不同。';

  @override
  String get profileStatusPlaceholder => '狀態訊息';

  @override
  String get profileArchives => '查看封存';

  @override
  String get profileEditAvatar => '編輯頭像';

  @override
  String get profileLinkedEmailAccounts => 'Email accounts';

  @override
  String get profileChangePassword => '更改密碼';

  @override
  String get profileDeleteAccount => '刪除帳戶';

  @override
  String get termsAcceptLabel => '我接受條款與條件';

  @override
  String get termsAgreementPrefix => '你同意我們的';

  @override
  String get termsAgreementTerms => '條款';

  @override
  String get termsAgreementAnd => ' 和 ';

  @override
  String get termsAgreementPrivacy => '隱私權政策';

  @override
  String get termsAgreementError => '你必須接受條款與條件';

  @override
  String get commonContinue => '繼續';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonSave => '儲存';

  @override
  String get commonRetry => '重試';

  @override
  String get commonRemove => '移除';

  @override
  String get commonSend => '傳送';

  @override
  String get commonDismiss => '關閉';

  @override
  String get settingsSectionImportant => '重要';

  @override
  String get settingsSectionAppearance => '外觀';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsThemeMode => '主題模式';

  @override
  String get settingsThemeModeSystem => '系統';

  @override
  String get settingsThemeModeLight => '淺色';

  @override
  String get settingsThemeModeDark => '深色';

  @override
  String get settingsColorScheme => '配色方案';

  @override
  String get settingsColorfulAvatars => '彩色頭像';

  @override
  String get settingsColorfulAvatarsDescription => '為每個頭像產生不同的背景顏色。';

  @override
  String get settingsLowMotion => '低動效';

  @override
  String get settingsLowMotionDescription => '停用大部分動畫，更適合較慢的裝置。';

  @override
  String get settingsSectionChats => '聊天';

  @override
  String get settingsMessageStorageTitle => '訊息儲存';

  @override
  String get settingsMessageStorageSubtitle => '本地會保留裝置副本；僅伺服器模式會查詢封存。';

  @override
  String get settingsMessageStorageLocal => '本地';

  @override
  String get settingsMessageStorageServerOnly => '僅伺服器';

  @override
  String get settingsMuteNotifications => '靜音通知';

  @override
  String get settingsMuteNotificationsDescription => '停止接收訊息通知。';

  @override
  String get settingsNotificationPreviews => '通知預覽';

  @override
  String get settingsNotificationPreviewsDescription => '在通知和鎖定畫面上顯示訊息內容。';

  @override
  String get settingsReadReceipts => '傳送已讀回條';

  @override
  String get settingsTypingIndicators => '傳送輸入指示';

  @override
  String get settingsTypingIndicatorsDescription => '讓聊天中的其他人看到你正在輸入。';

  @override
  String get settingsShareTokenFooter => '包含分享代幣頁腳';

  @override
  String get settingsShareTokenFooterDescription =>
      '有助於保持多收件人郵件執行緒與附件關聯。關閉後可能造成執行緒中斷。';

  @override
  String get authCustomServerTitle => '自訂伺服器';

  @override
  String get authCustomServerDescription =>
      '覆寫 XMPP/SMTP 端點或啟用 DNS 查詢。欄位留空以保留預設值。';

  @override
  String get authCustomServerDomainOrIp => '網域或 IP';

  @override
  String get authCustomServerXmppLabel => 'XMPP';

  @override
  String get authCustomServerSmtpLabel => 'SMTP';

  @override
  String get authCustomServerUseDns => '使用 DNS';

  @override
  String get authCustomServerUseSrv => '使用 SRV';

  @override
  String get authCustomServerRequireDnssec => '需要 DNSSEC';

  @override
  String get authCustomServerXmppHostPlaceholder => 'XMPP 主機（可選）';

  @override
  String get authCustomServerPortPlaceholder => '連接埠';

  @override
  String get authCustomServerSmtpHostPlaceholder => 'SMTP 主機（可選）';

  @override
  String get authCustomServerImapHostPlaceholder => 'IMAP 主機（可選）';

  @override
  String get authCustomServerApiPortPlaceholder => 'API 連接埠';

  @override
  String get authCustomServerReset => '重設為 axi.im';

  @override
  String get authCustomServerOpenSettings => '開啟自訂伺服器設定';

  @override
  String get authCustomServerAdvancedHint => '進階伺服器選項會保持隱藏，直到你點擊使用者名稱的後綴。';

  @override
  String get authUnregisterTitle => '註銷';

  @override
  String get authUnregisterConfirmTitle => 'Delete account?';

  @override
  String get authUnregisterConfirmMessage =>
      'This will permanently delete your account and local data. This cannot be undone.';

  @override
  String get authUnregisterConfirmAction => 'Delete account';

  @override
  String get authUnregisterProgressLabel => '正在等待刪除帳戶';

  @override
  String get authPasswordPlaceholder => '密碼';

  @override
  String get authPasswordCurrentPlaceholder => '舊密碼';

  @override
  String get authPasswordNewPlaceholder => '新密碼';

  @override
  String get authPasswordConfirmNewPlaceholder => '確認新密碼';

  @override
  String get authChangePasswordProgressLabel => '正在等待變更密碼';

  @override
  String get authLogoutTitle => '登出';

  @override
  String get authLogoutNormal => '登出';

  @override
  String get authLogoutNormalDescription => '登出此帳戶。';

  @override
  String get authLogoutBurn => '銷毀帳戶';

  @override
  String get authLogoutBurnDescription => '登出並清除此帳戶的本機資料。';

  @override
  String get chatAttachmentBlockedTitle => '附件已被阻擋';

  @override
  String get chatAttachmentBlockedDescription => '僅在你信任未知聯絡人時才載入附件。你同意後我們才會擷取。';

  @override
  String get chatAttachmentLoad => '載入附件';

  @override
  String get chatAttachmentUnavailable => '附件無法使用';

  @override
  String get chatAttachmentSendFailed => '無法傳送附件。';

  @override
  String get chatAttachmentRetryUpload => '重試上傳';

  @override
  String get chatAttachmentRemoveAttachment => '移除附件';

  @override
  String get chatAttachmentStatusUploading => '正在上傳附件…';

  @override
  String get chatAttachmentStatusQueued => '等待傳送';

  @override
  String get chatAttachmentStatusFailed => '上傳失敗';

  @override
  String get chatAttachmentLoading => '正在載入附件';

  @override
  String chatAttachmentLoadingProgress(Object percent) {
    return '正在載入 $percent';
  }

  @override
  String get chatAttachmentDownload => '下載附件';

  @override
  String get chatAttachmentDownloadAndOpen => '下載並開啟';

  @override
  String get chatAttachmentDownloadAndSave => '下載並儲存';

  @override
  String get chatAttachmentDownloadAndShare => '下載並分享';

  @override
  String get chatAttachmentExportTitle => '儲存附件？';

  @override
  String get chatAttachmentExportMessage =>
      '這會把附件複製到共享儲存空間。匯出內容未加密，可能會被其他應用程式讀取。繼續？';

  @override
  String get chatAttachmentExportConfirm => '儲存';

  @override
  String get chatAttachmentExportCancel => '取消';

  @override
  String get chatMediaMetadataWarningTitle => '媒體可能包含中繼資料';

  @override
  String get chatMediaMetadataWarningMessage => '相片和影片可能包含位置及裝置資訊。繼續？';

  @override
  String get chatNotificationPreviewOptionInherit => '使用應用程式設定';

  @override
  String get chatNotificationPreviewOptionShow => '一律顯示預覽';

  @override
  String get chatNotificationPreviewOptionHide => '一律隱藏預覽';

  @override
  String get chatAttachmentUnavailableDevice => '此裝置上已無法取得該附件';

  @override
  String get chatAttachmentInvalidLink => '無效的附件連結';

  @override
  String chatAttachmentOpenFailed(Object target) {
    return '無法開啟 $target';
  }

  @override
  String get chatAttachmentTypeMismatchTitle => 'Attachment type mismatch';

  @override
  String chatAttachmentTypeMismatchMessage(Object declared, Object detected) {
    return 'This attachment says it is $declared, but the file looks like $detected. Opening it could be unsafe. Continue?';
  }

  @override
  String get chatAttachmentTypeMismatchConfirm => 'Open anyway';

  @override
  String get chatAttachmentHighRiskTitle => 'Potentially unsafe file';

  @override
  String get chatAttachmentHighRiskMessage =>
      'This file type can be dangerous to open. We recommend saving it and scanning it before opening. Continue?';

  @override
  String get chatAttachmentUnknownSize => '大小未知';

  @override
  String get chatAttachmentNotDownloadedYet => 'Not downloaded yet';

  @override
  String chatAttachmentErrorTooltip(Object message, Object fileName) {
    return '$message（$fileName）';
  }

  @override
  String get chatAttachmentMenuHint => '開啟選單以取得更多動作。';

  @override
  String get accessibilityActionsLabel => '無障礙操作';

  @override
  String accessibilityActionsShortcutTooltip(Object shortcut) {
    return '無障礙操作（$shortcut）';
  }

  @override
  String get shorebirdUpdateAvailable => '有可用更新：請登出並重新啟動應用程式。';

  @override
  String get calendarEditTaskTitle => '編輯任務';

  @override
  String get calendarDateTimeLabel => '日期與時間';

  @override
  String get calendarSelectDate => '選擇日期';

  @override
  String get calendarSelectTime => '選擇時間';

  @override
  String get calendarDurationLabel => '時長';

  @override
  String get calendarSelectDuration => '選擇時長';

  @override
  String get calendarAddToCriticalPath => '新增到關鍵路徑';

  @override
  String get calendarNoCriticalPathMembership => '不在任何關鍵路徑中';

  @override
  String get calendarGuestTitle => '訪客行事曆';

  @override
  String get calendarGuestBanner => '訪客模式 - 不同步';

  @override
  String get calendarGuestModeLabel => '訪客模式';

  @override
  String get calendarGuestModeDescription => '登入以同步任務並啟用提醒。';

  @override
  String get calendarNoTasksForDate => '此日期沒有任務';

  @override
  String get calendarTapToCreateTask => '點擊 + 建立新任務';

  @override
  String get calendarQuickStats => '快速統計';

  @override
  String get calendarDueReminders => '到期提醒';

  @override
  String get calendarNextTaskLabel => '下一個任務';

  @override
  String get calendarNone => '無';

  @override
  String get calendarViewLabel => '檢視';

  @override
  String get calendarViewDay => '日';

  @override
  String get calendarViewWeek => '週';

  @override
  String get calendarViewMonth => '月';

  @override
  String get calendarPreviousDate => '前一日期';

  @override
  String get calendarNextDate => '下一日期';

  @override
  String calendarPreviousUnit(Object unit) {
    return '上一個$unit';
  }

  @override
  String calendarNextUnit(Object unit) {
    return '下一個$unit';
  }

  @override
  String get calendarToday => '今天';

  @override
  String get calendarUndo => '復原';

  @override
  String get calendarRedo => '重做';

  @override
  String get calendarOpeningCreator => '正在開啟任務建立器...';

  @override
  String calendarWeekOf(Object date) {
    return '本週 $date';
  }

  @override
  String get calendarStatusCompleted => '已完成';

  @override
  String get calendarStatusOverdue => '已過期';

  @override
  String get calendarStatusDueSoon => '即將到期';

  @override
  String get calendarStatusPending => '待處理';

  @override
  String get calendarTaskCompletedMessage => '任務已完成！';

  @override
  String get calendarTaskUpdatedMessage => '任務已更新！';

  @override
  String get calendarErrorTitle => '錯誤';

  @override
  String get calendarErrorTaskNotFound => '找不到任務';

  @override
  String get calendarErrorTitleEmpty => '標題不能為空';

  @override
  String get calendarErrorTitleTooLong => '標題過長';

  @override
  String get calendarErrorDescriptionTooLong => '描述過長';

  @override
  String get calendarErrorInputInvalid => '輸入無效';

  @override
  String get calendarErrorAddFailed => '新增任務失敗';

  @override
  String get calendarErrorUpdateFailed => '更新任務失敗';

  @override
  String get calendarErrorDeleteFailed => '刪除任務失敗';

  @override
  String get calendarErrorNetwork => '網路錯誤';

  @override
  String get calendarErrorStorage => '儲存錯誤';

  @override
  String get calendarErrorUnknown => '未知錯誤';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonOpen => '開啟';

  @override
  String get commonSelect => '選擇';

  @override
  String get commonExport => '匯出';

  @override
  String get commonFavorite => '收藏';

  @override
  String get commonUnfavorite => '取消收藏';

  @override
  String get commonArchive => '封存';

  @override
  String get commonUnarchive => '取消封存';

  @override
  String get commonShow => '顯示';

  @override
  String get commonHide => '隱藏';

  @override
  String get blocklistBlockUser => '封鎖用戶';

  @override
  String get blocklistWaitingForUnblock => '等待解除封鎖';

  @override
  String get blocklistUnblockAll => '全部解除封鎖';

  @override
  String get blocklistUnblock => '解除封鎖';

  @override
  String get blocklistBlock => '封鎖';

  @override
  String get blocklistAddTooltip => '加入封鎖清單';

  @override
  String get mucChangeNickname => '更改暱稱';

  @override
  String mucChangeNicknameWithCurrent(Object current) {
    return '更改暱稱（目前：$current）';
  }

  @override
  String get mucLeaveRoom => '離開聊天室';

  @override
  String get mucNoMembers => '暫無成員';

  @override
  String get mucInviteUsers => '邀請用戶';

  @override
  String get mucSendInvites => '發送邀請';

  @override
  String get mucChangeNicknameTitle => '更改暱稱';

  @override
  String get mucEnterNicknamePlaceholder => '輸入暱稱';

  @override
  String get mucUpdateNickname => '更新';

  @override
  String get mucMembersTitle => '成員';

  @override
  String get mucInviteUser => '邀請用戶';

  @override
  String get mucSectionOwners => '擁有者';

  @override
  String get mucSectionAdmins => '管理員';

  @override
  String get mucSectionModerators => '版主';

  @override
  String get mucSectionMembers => '成員';

  @override
  String get mucSectionVisitors => '訪客';

  @override
  String get mucRoleOwner => '擁有者';

  @override
  String get mucRoleAdmin => '管理員';

  @override
  String get mucRoleMember => '成員';

  @override
  String get mucRoleVisitor => '訪客';

  @override
  String get mucRoleModerator => '版主';

  @override
  String get mucActionKick => '移出';

  @override
  String get mucActionBan => '封禁';

  @override
  String get mucActionMakeMember => '設為成員';

  @override
  String get mucActionMakeAdmin => '設為管理員';

  @override
  String get mucActionMakeOwner => '設為擁有者';

  @override
  String get mucActionGrantModerator => '授予版主';

  @override
  String get mucActionRevokeModerator => '取消版主';

  @override
  String get chatsEmptyList => '暫時沒有聊天';

  @override
  String chatsDeleteConfirmMessage(Object chatTitle) {
    return '刪除聊天：$chatTitle';
  }

  @override
  String get chatsDeleteMessagesOption => '永久刪除訊息';

  @override
  String get chatsDeleteSuccess => '聊天已刪除';

  @override
  String get chatsExportNoContent => '沒有可匯出的文字內容';

  @override
  String get chatsExportShareText => '來自 Axichat 的聊天匯出';

  @override
  String chatsExportShareSubject(Object chatTitle) {
    return '與 $chatTitle 的聊天';
  }

  @override
  String get chatsExportSuccess => '聊天已匯出';

  @override
  String get chatsExportFailure => '無法匯出聊天';

  @override
  String get chatExportWarningTitle => '匯出聊天記錄？';

  @override
  String get chatExportWarningMessage => '聊天匯出未加密，可能會被其他應用程式或雲端服務讀取。繼續？';

  @override
  String get chatsArchivedRestored => '聊天已還原';

  @override
  String get chatsArchivedHint => '聊天已封存（個人檔案 → 已封存聊天）';

  @override
  String get chatsVisibleNotice => '聊天已重新可見';

  @override
  String get chatsHiddenNotice => '聊天已隱藏（使用篩選顯示）';

  @override
  String chatsUnreadLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 則未讀訊息',
      zero: '沒有未讀訊息',
    );
    return '$_temp0';
  }

  @override
  String get chatsSemanticsUnselectHint => '點擊取消選取聊天';

  @override
  String get chatsSemanticsSelectHint => '點擊選取聊天';

  @override
  String get chatsSemanticsOpenHint => '點擊開啟聊天';

  @override
  String get chatsHideActions => '隱藏聊天操作';

  @override
  String get chatsShowActions => '顯示聊天操作';

  @override
  String get chatsSelectedLabel => '聊天已選取';

  @override
  String get chatsSelectLabel => '選取聊天';

  @override
  String get chatsExportFileLabel => 'chats';

  @override
  String get chatSelectionExportEmptyTitle => '沒有可匯出的訊息';

  @override
  String get chatSelectionExportEmptyMessage => '選擇包含文字內容的聊天';

  @override
  String get chatSelectionExportShareText => '來自 Axichat 的聊天匯出';

  @override
  String get chatSelectionExportShareSubject => 'Axichat 聊天匯出';

  @override
  String get chatSelectionExportReadyTitle => '匯出完成';

  @override
  String chatSelectionExportReadyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已分享 # 個聊天',
      one: '已分享 # 個聊天',
    );
    return '$_temp0';
  }

  @override
  String get chatSelectionExportFailedTitle => '匯出失敗';

  @override
  String get chatSelectionExportFailedMessage => '無法匯出所選聊天';

  @override
  String get chatSelectionDeleteConfirmTitle => '刪除聊天？';

  @override
  String chatSelectionDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '將刪除 # 個聊天及其所有訊息，無法復原。',
      one: '將刪除 1 個聊天及其所有訊息，無法復原。',
    );
    return '$_temp0';
  }

  @override
  String get chatsCreateGroupChatTooltip => '建立群組聊天';

  @override
  String get chatsRoomLabel => '聊天室';

  @override
  String get chatsCreateChatRoomTitle => '建立聊天室';

  @override
  String get chatsRoomNamePlaceholder => '名稱';

  @override
  String get chatsArchiveTitle => '封存';

  @override
  String get chatsArchiveEmpty => '暫無已封存的聊天';

  @override
  String calendarTileNow(Object title) {
    return '現在：$title';
  }

  @override
  String calendarTileNext(Object title) {
    return '下一個：$title';
  }

  @override
  String get calendarTileNone => '沒有即將進行的任務';

  @override
  String get calendarViewDayShort => '日';

  @override
  String get calendarViewWeekShort => '週';

  @override
  String get calendarViewMonthShort => '月';

  @override
  String get calendarShowCompleted => '顯示已完成';

  @override
  String get calendarHideCompleted => '隱藏已完成';

  @override
  String get rosterAddTooltip => '加入聯絡人';

  @override
  String get rosterAddLabel => '聯絡人';

  @override
  String get rosterAddTitle => '新增聯絡人';

  @override
  String get rosterEmpty => '暫無聯絡人';

  @override
  String get rosterCompose => '撰寫';

  @override
  String rosterRemoveConfirm(Object jid) {
    return '將 $jid 從聯絡人移除？';
  }

  @override
  String get rosterInvitesEmpty => '暫無邀請';

  @override
  String rosterRejectInviteConfirm(Object jid) {
    return '拒絕來自 $jid 的邀請？';
  }

  @override
  String get rosterAddContactTooltip => '新增聯絡人';

  @override
  String get jidInputPlaceholder => 'john@axi.im';

  @override
  String get jidInputInvalid => '請輸入有效的 JID';

  @override
  String get sessionCapabilityChat => '聊天';

  @override
  String get sessionCapabilityEmail => '電郵';

  @override
  String get sessionCapabilityStatusConnected => '已連線';

  @override
  String get sessionCapabilityStatusConnecting => '連線中';

  @override
  String get sessionCapabilityStatusError => '錯誤';

  @override
  String get sessionCapabilityStatusOffline => '離線';

  @override
  String get sessionCapabilityStatusOff => '關閉';

  @override
  String get sessionCapabilityStatusSyncing => '同步中';

  @override
  String get authChangePasswordPending => '正在更新密碼...';

  @override
  String get authEndpointAdvancedHint => '進階選項';

  @override
  String get authEndpointApiPortPlaceholder => 'API 埠';

  @override
  String get authEndpointDescription => '為此帳戶設定 XMPP/SMTP 端點。';

  @override
  String get authEndpointDomainPlaceholder => '網域';

  @override
  String get authEndpointPortPlaceholder => '埠';

  @override
  String get authEndpointRequireDnssecLabel => '需要 DNSSEC';

  @override
  String get authEndpointReset => '重設';

  @override
  String get authEndpointSmtpHostPlaceholder => 'SMTP 主機';

  @override
  String get authEndpointSmtpLabel => 'SMTP';

  @override
  String get authEndpointTitle => '端點設定';

  @override
  String get authEndpointUseDnsLabel => '使用 DNS';

  @override
  String get authEndpointUseSrvLabel => '使用 SRV';

  @override
  String get authEndpointXmppHostPlaceholder => 'XMPP 主機';

  @override
  String get authEndpointXmppLabel => 'XMPP';

  @override
  String get authUnregisterPending => '正在取消註冊...';

  @override
  String calendarAddTaskError(Object details) {
    return '無法新增任務：$details';
  }

  @override
  String get calendarBackToCalendar => '返回日曆';

  @override
  String get calendarCriticalPathAddTask => '新增任務';

  @override
  String get calendarCriticalPathAddToTitle => '加入關鍵路徑';

  @override
  String get calendarCriticalPathCreatePrompt => '建立關鍵路徑以開始';

  @override
  String get calendarCriticalPathDragHint => '拖曳任務以重新排序';

  @override
  String get calendarCriticalPathEmptyTasks => '此路徑中暫時沒有任務';

  @override
  String get calendarCriticalPathNameEmptyError => '請輸入名稱';

  @override
  String get calendarCriticalPathNamePlaceholder => '關鍵路徑名稱';

  @override
  String get calendarCriticalPathNamePrompt => '名稱';

  @override
  String get calendarCriticalPathTaskOrderTitle => '排列任務';

  @override
  String get calendarCriticalPathsAll => '所有路徑';

  @override
  String get calendarCriticalPathsEmpty => '暫時沒有關鍵路徑';

  @override
  String get calendarCriticalPathsNew => '新增關鍵路徑';

  @override
  String get calendarCriticalPathsTitle => '關鍵路徑';

  @override
  String calendarDeleteTaskConfirm(Object title) {
    return '刪除「$title」？';
  }

  @override
  String get calendarErrorTitleEmptyFriendly => '標題不能為空';

  @override
  String get calendarExportFormatIcsSubtitle => '供日曆用戶端使用';

  @override
  String get calendarExportFormatIcsTitle => '匯出 .ics';

  @override
  String get calendarExportFormatJsonSubtitle => '用於備份或腳本';

  @override
  String get calendarExportFormatJsonTitle => '匯出 JSON';

  @override
  String calendarRemovePathConfirm(Object name) {
    return '要將此任務從「$name」移除？';
  }

  @override
  String get calendarSandboxHint => '先在此規劃任務，再分配到路徑。';

  @override
  String get chatAlertHide => '隱藏';

  @override
  String get chatAlertIgnore => '忽略';

  @override
  String get chatAttachmentTapToLoad => '點擊載入';

  @override
  String chatMessageAddRecipientSuccess(Object recipient) {
    return '已新增 $recipient';
  }

  @override
  String get chatMessageAddRecipients => '新增收件人';

  @override
  String get chatMessageCreateChat => '建立聊天';

  @override
  String chatMessageCreateChatFailure(Object reason) {
    return '無法建立聊天：$reason';
  }

  @override
  String get chatMessageInfoDevice => '裝置';

  @override
  String get chatMessageInfoError => '錯誤';

  @override
  String get chatMessageInfoProtocol => '通訊協定';

  @override
  String get chatMessageInfoTimestamp => '時間戳記';

  @override
  String get chatMessageOpenChat => '開啟聊天';

  @override
  String get chatMessageStatusDisplayed => '已讀';

  @override
  String get chatMessageStatusReceived => '已接收';

  @override
  String get chatMessageStatusSent => '已傳送';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String emailDemoAccountLabel(Object account) {
    return 'Account: $account';
  }

  @override
  String get emailDemoDefaultMessage => 'Hello from Axichat';

  @override
  String get emailDemoDisplayNameSelf => 'Self';

  @override
  String get emailDemoErrorMissingPassphrase => 'Missing database passphrase.';

  @override
  String get emailDemoErrorMissingPrefix => 'Missing database prefix.';

  @override
  String get emailDemoErrorMissingProfile =>
      'No primary profile found. Log in first.';

  @override
  String get emailDemoMessageLabel => 'Demo message';

  @override
  String get emailDemoProvisionButton => 'Provision Email';

  @override
  String get emailDemoSendButton => 'Send Demo Message';

  @override
  String get emailDemoStatusIdle => 'Idle';

  @override
  String emailDemoStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get emailDemoStatusLoginToProvision => 'Log in to provision email.';

  @override
  String get emailDemoStatusNotProvisioned => 'Not provisioned';

  @override
  String emailDemoStatusProvisionFailed(Object error) {
    return 'Provisioning failed: $error';
  }

  @override
  String get emailDemoStatusProvisionFirst => 'Provision an account first.';

  @override
  String emailDemoStatusProvisioned(Object address) {
    return 'Provisioned $address';
  }

  @override
  String get emailDemoStatusProvisioning => 'Provisioning email account…';

  @override
  String get emailDemoStatusReady => 'Ready';

  @override
  String emailDemoStatusSendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get emailDemoStatusSending => 'Sending demo message…';

  @override
  String emailDemoStatusSent(Object id) {
    return 'Sent demo message (id=$id)';
  }

  @override
  String get emailDemoTitle => 'Email Transport Demo';

  @override
  String get linkedEmailAccountsTitle => 'Email accounts';

  @override
  String get linkedEmailAccountsDescription =>
      'Link existing inboxes and send from multiple addresses.';

  @override
  String get linkedEmailAccountsDefaultHint =>
      'New chats send from your default address unless you switch it per chat.';

  @override
  String linkedEmailAccountsLimitHint(Object limit) {
    return 'Up to $limit extra accounts.';
  }

  @override
  String get linkedEmailAccountsLinkAction => 'Link account';

  @override
  String get linkedEmailAccountsUnsupportedHint =>
      'This device supports one email account at a time.';

  @override
  String get linkedEmailAccountsEmptyTitle => 'No linked accounts yet';

  @override
  String get linkedEmailAccountsEmptyDescription =>
      'Add an existing inbox to sync mail and send from it.';

  @override
  String get linkedEmailAccountsLoadFailure => 'Unable to load email accounts.';

  @override
  String get linkedEmailAccountsMakeDefaultAction => 'Make default';

  @override
  String get linkedEmailAccountsUpdatePasswordAction => 'Update password';

  @override
  String get linkedEmailAccountsDefaultBadge => 'Default';

  @override
  String get linkedEmailAccountsRemoveTitle => 'Remove linked account?';

  @override
  String get linkedEmailAccountsRemoveDescription =>
      'You can re-link later. Existing messages stay.';

  @override
  String get linkedEmailAccountsUpdateTitle => 'Update email password';

  @override
  String get linkedEmailAccountsAccountLabel => 'Account';

  @override
  String get linkedEmailAccountsSheetTitle => 'Link an email account';

  @override
  String get linkedEmailAccountsSheetSubtitle =>
      'Use an app password if your provider requires it.';

  @override
  String get linkedEmailAccountsAddressPlaceholder => 'name@domain.com';

  @override
  String get linkedEmailAccountsAddressRequired => 'Enter an email address.';

  @override
  String get linkedEmailAccountsAddressInvalid =>
      'Enter a valid email address.';

  @override
  String get linkedEmailAccountsPasswordPlaceholder => 'Enter app password';

  @override
  String get linkedEmailAccountsPasswordLabel => 'App password';

  @override
  String get linkedEmailAccountsSetDefaultLabel =>
      'Set as default send address';

  @override
  String get linkedEmailAccountsSetDefaultDescription =>
      'New chats send from this address by default.';

  @override
  String linkedEmailAccountsLimitReached(Object limit) {
    return 'You can link up to $limit extra accounts.';
  }

  @override
  String get linkedEmailAccountsUnsupportedError =>
      'Multiple accounts are not supported on this device.';

  @override
  String get linkedEmailAccountsLinkFailure => 'Unable to link account.';

  @override
  String get linkedEmailAccountsUnlinkFailure => 'Unable to remove account.';

  @override
  String get linkedEmailAccountsDefaultFailure =>
      'Unable to update default address.';

  @override
  String get linkedEmailAccountsUpdateFailure => 'Unable to update password.';

  @override
  String get verificationAddLabelPlaceholder => 'Add label';

  @override
  String get verificationCurrentDevice => 'Current device';

  @override
  String verificationDeviceIdLabel(Object id) {
    return 'ID: $id';
  }

  @override
  String get verificationNotTrusted => 'Not trusted';

  @override
  String get verificationRegenerateDevice => 'Regenerate device';

  @override
  String get verificationRegenerateWarning =>
      'Only do this if you are an expert.';

  @override
  String get verificationTrustBlind => 'Blind trust';

  @override
  String get verificationTrustNone => 'No trust';

  @override
  String get verificationTrustVerified => 'Verified';

  @override
  String get verificationTrusted => 'Trusted';

  @override
  String get avatarSavedMessage => 'Avatar saved.';

  @override
  String get avatarCropTitle => 'Crop & focus';

  @override
  String get avatarCropDescription =>
      'Drag or resize the square to set your crop. Reset to center and follow the circle to match the saved avatar.';

  @override
  String get avatarCropPlaceholder =>
      'Add a photo or pick a default avatar to adjust the framing.';

  @override
  String avatarCropSizeLabel(Object pixels) {
    return '$pixels px crop';
  }

  @override
  String get avatarCropSavedSize => 'Saved at 256×256 • < 64 KB';

  @override
  String get avatarBackgroundTitle => 'Background color';

  @override
  String get avatarBackgroundDescription =>
      'Use the wheel or presets to tint transparent avatars before saving.';

  @override
  String get avatarBackgroundWheelTitle => 'Wheel & hex';

  @override
  String get avatarBackgroundWheelDescription =>
      'Drag the wheel or enter a hex value.';

  @override
  String get avatarBackgroundTransparent => 'Transparent';

  @override
  String get avatarBackgroundPreview => 'Preview saved circle tint.';

  @override
  String get avatarDefaultsTitle => 'Default avatars';

  @override
  String get avatarCategoryAbstract => 'Abstract';

  @override
  String get avatarCategoryStem => 'STEM';

  @override
  String get avatarCategorySports => 'Sports';

  @override
  String get avatarCategoryMusic => 'Music';

  @override
  String get avatarCategoryMisc => 'Hobbies & Games';

  @override
  String avatarTemplateAbstract(Object index) {
    return 'Abstract $index';
  }

  @override
  String get avatarTemplateAtom => 'Atom';

  @override
  String get avatarTemplateBeaker => 'Beaker';

  @override
  String get avatarTemplateCompass => 'Compass';

  @override
  String get avatarTemplateCpu => 'CPU';

  @override
  String get avatarTemplateGear => 'Gear';

  @override
  String get avatarTemplateGlobe => 'Globe';

  @override
  String get avatarTemplateLaptop => 'Laptop';

  @override
  String get avatarTemplateMicroscope => 'Microscope';

  @override
  String get avatarTemplateRobot => 'Robot';

  @override
  String get avatarTemplateStethoscope => 'Stethoscope';

  @override
  String get avatarTemplateTelescope => 'Telescope';

  @override
  String get avatarTemplateArchery => 'Archery';

  @override
  String get avatarTemplateBaseball => 'Baseball';

  @override
  String get avatarTemplateBasketball => 'Basketball';

  @override
  String get avatarTemplateBoxing => 'Boxing';

  @override
  String get avatarTemplateCycling => 'Cycling';

  @override
  String get avatarTemplateDarts => 'Darts';

  @override
  String get avatarTemplateFootball => 'Football';

  @override
  String get avatarTemplateGolf => 'Golf';

  @override
  String get avatarTemplatePingPong => 'Ping Pong';

  @override
  String get avatarTemplateSkiing => 'Skiing';

  @override
  String get avatarTemplateSoccer => 'Soccer';

  @override
  String get avatarTemplateTennis => 'Tennis';

  @override
  String get avatarTemplateVolleyball => 'Volleyball';

  @override
  String get avatarTemplateDrums => 'Drums';

  @override
  String get avatarTemplateElectricGuitar => 'Electric Guitar';

  @override
  String get avatarTemplateGuitar => 'Guitar';

  @override
  String get avatarTemplateMicrophone => 'Microphone';

  @override
  String get avatarTemplatePiano => 'Piano';

  @override
  String get avatarTemplateSaxophone => 'Saxophone';

  @override
  String get avatarTemplateViolin => 'Violin';

  @override
  String get avatarTemplateCards => 'Cards';

  @override
  String get avatarTemplateChess => 'Chess';

  @override
  String get avatarTemplateChessAlt => 'Chess Alt';

  @override
  String get avatarTemplateDice => 'Dice';

  @override
  String get avatarTemplateDiceAlt => 'Dice Alt';

  @override
  String get avatarTemplateEsports => 'Esports';

  @override
  String get avatarTemplateSword => 'Sword';

  @override
  String get avatarTemplateVideoGames => 'Video Games';

  @override
  String get avatarTemplateVideoGamesAlt => 'Video Games Alt';

  @override
  String get commonDone => '完成';

  @override
  String get commonRename => '重新命名';

  @override
  String get calendarHour => '小時';

  @override
  String get calendarMinute => '分鐘';

  @override
  String get calendarPasteTaskHere => '在此貼上任務';

  @override
  String get calendarQuickAddTask => '快速新增任務';

  @override
  String get calendarSplitTaskAt => '拆分任務於';

  @override
  String get calendarAddDayEvent => '新增日程事件';

  @override
  String get calendarZoomOut => '縮小 (Ctrl/Cmd + -)';

  @override
  String get calendarZoomIn => '放大 (Ctrl/Cmd + +)';

  @override
  String get calendarChecklistItem => '清單項目';

  @override
  String get calendarRemoveItem => '移除項目';

  @override
  String get calendarAddChecklistItem => '新增清單項目';

  @override
  String get calendarRepeatTimes => '重複次數';

  @override
  String get calendarDayEventHint => '生日、節日或備註';

  @override
  String get calendarOptionalDetails => '可選詳情';

  @override
  String get calendarDates => '日期';

  @override
  String get calendarTaskTitleHint => '任務標題';

  @override
  String get calendarDescriptionOptionalHint => '描述（可選）';

  @override
  String get calendarLocationOptionalHint => '地點（可選）';

  @override
  String get calendarCloseTooltip => '關閉';

  @override
  String get calendarAddTaskInputHint => '新增任務...（例如『明天下午3點開會』）';

  @override
  String get calendarBranch => '分支';

  @override
  String get calendarPickDifferentTask => '為此時段選擇其他任務';

  @override
  String get calendarSyncRequest => '請求';

  @override
  String get calendarSyncPush => '推送';

  @override
  String get calendarImportant => '重要';

  @override
  String get calendarUrgent => '緊急';

  @override
  String get calendarClearSchedule => '清除日程';

  @override
  String get calendarEditTaskTooltip => '編輯任務';

  @override
  String get calendarDeleteTaskTooltip => '刪除任務';

  @override
  String get calendarBackToChats => '返回聊天';

  @override
  String get calendarBackToLogin => '返回登入';

  @override
  String get calendarRemindersSection => '提醒';

  @override
  String get settingsAutoLoadEmailImages => '自動載入電郵圖片';

  @override
  String get settingsAutoLoadEmailImagesDescription => '可能會向寄件人洩露您的IP地址';

  @override
  String get settingsAutoDownloadImages => 'Auto-download images';

  @override
  String get settingsAutoDownloadImagesDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadVideos => 'Auto-download videos';

  @override
  String get settingsAutoDownloadVideosDescription => 'Only for trusted chats.';

  @override
  String get settingsAutoDownloadDocuments => 'Auto-download documents';

  @override
  String get settingsAutoDownloadDocumentsDescription =>
      'Only for trusted chats.';

  @override
  String get settingsAutoDownloadArchives => 'Auto-download archives';

  @override
  String get settingsAutoDownloadArchivesDescription =>
      'Only for trusted chats.';

  @override
  String get chatChooseTextToAdd => '選擇要新增的文字';
}
