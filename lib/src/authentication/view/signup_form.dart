import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/widgets/endpoint_config_sheet.dart';
import 'package:axichat/src/authentication/view/terms_checkbox.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/profile/avatar/avatar_image_utils.dart';
import 'package:axichat/src/profile/avatar/avatar_templates.dart';
import 'package:axichat/src/profile/bloc/avatar_editor_cubit.dart'
    show AvatarEditorCubit;
import 'package:axichat/src/profile/view/widgets/avatar_cropper.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:xml/xml.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({
    super.key,
    this.onSubmitStart,
    this.onLoadingChanged,
  });

  final VoidCallback? onSubmitStart;
  final ValueChanged<bool>? onLoadingChanged;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

enum _PasswordStrengthLevel { empty, weak, medium, stronger }

enum _InsecurePasswordReason { weak, breached }

enum _AvatarEditorMode { none, colorOnly, cropOnly }

const _strengthMediumColor = Color(0xFFF97316);
const _strengthStrongColor = Color(0xFF22C55E);

class _SignupFormState extends State<SignupForm>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _jidTextController;
  late TextEditingController _passwordTextController;
  late TextEditingController _password2TextController;
  late TextEditingController _captchaTextController;
  final _rememberMeFieldKey = GlobalKey<FormFieldState<bool>>();
  static final _usernamePattern = RegExp(r'^[a-z][a-z0-9._-]{3,19}$');
  static final _digitCharacters = RegExp(r'[0-9]');
  static final _lowercaseCharacters = RegExp(r'[a-z]');
  static final _uppercaseCharacters = RegExp(r'[A-Z]');
  static final _symbolCharacters = RegExp(r'[^A-Za-z0-9]');
  static const double _maxEntropyBits = 120;
  static const double _weakEntropyThreshold = 50;
  static const double _strongEntropyThreshold = 80;
  static const int _avatarTargetSize = 256;
  static const int _avatarMaxBytes = 64 * 1024;
  static const int _avatarMinJpegQuality = 35;
  static const int _avatarQualityStep = 5;
  static const double _avatarInsetFraction =
      AvatarEditorCubit.avatarInsetFraction;
  static const double _avatarTransparentInsetFraction =
      AvatarEditorCubit.transparentAvatarInsetFraction;

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  bool allowInsecurePassword = false;
  bool rememberMe = true;
  bool _passwordBreached = false;
  String? _lastBreachedPassword;
  bool _pwnedCheckInProgress = false;
  bool _showAllowInsecureError = false;
  bool _showBreachedError = false;
  String _lastPasswordValue = '';
  int _allowInsecureResetTick = 0;
  bool _captchaHasLoadedOnce = false;
  Timer? _captchaRetryTimer;
  String? _lastCaptchaServer;
  AvatarUploadPayload? _signupAvatar;
  Uint8List? _signupAvatarPreview;
  Uint8List? _carouselAvatarPreview;
  _CarouselAvatar? _currentCarouselAvatar;
  final ValueNotifier<Uint8List?> _avatarPreviewNotifier =
      ValueNotifier<Uint8List?>(null);
  AvatarTemplate? _selectedTemplate;
  bool _showAvatarEditor = false;
  final List<_CarouselAvatar> _carouselBuffer = <_CarouselAvatar>[];
  late final List<AvatarTemplate> _avatarTemplates =
      buildDefaultAvatarTemplates();
  late final List<AvatarTemplate> _abstractAvatarTemplates = _avatarTemplates
      .where(
        (template) => template.category == AvatarTemplateCategory.abstract,
      )
      .toList();
  late final List<AvatarTemplate> _nonAbstractAvatarTemplates = _avatarTemplates
      .where(
        (template) => template.category != AvatarTemplateCategory.abstract,
      )
      .toList();
  final List<String> _recentCarouselAvatarIds = <String>[];
  static const _avatarCarouselInterval = Duration(seconds: 1);
  static const _avatarCarouselInitialBuffer = 4;
  static const _avatarCarouselSustainBuffer = 3;
  static const _avatarCarouselHistoryLimit = 12;
  final List<AvatarTemplate> _abstractCarouselBag = <AvatarTemplate>[];
  final List<AvatarTemplate> _nonAbstractCarouselBag = <AvatarTemplate>[];
  bool _nonAbstractAvatarsReady = false;
  bool _warmingNonAbstractAvatars = false;
  Timer? _avatarCarouselTimer;
  bool _avatarCarouselPrefilling = false;
  bool _avatarInitialized = false;
  bool _avatarProcessing = false;
  String? _avatarError;
  Color _avatarBackground = Colors.transparent;
  Rect? _signupCropRect;
  Uint8List? _signupSourceBytes;
  double? _signupImageWidth;
  double? _signupImageHeight;
  Timer? _signupRebuildTimer;
  img.Image? _signupSourceImage;
  final _random = math.Random();

  var _currentIndex = 0;
  String? _errorText;
  bool? _lastReportedLoading;
  late Future<String> _captchaSrc;
  bool _captchaSrcInitialized = false;

  @override
  void initState() {
    super.initState();
    _jidTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _passwordTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _password2TextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _captchaTextController = TextEditingController()
      ..addListener(_handleFieldProgressChanged);
    _restoreRememberMePreference();
  }

  Future<void> _restoreRememberMePreference() async {
    final preference =
        await context.read<AuthenticationCubit>().loadRememberMeChoice();
    if (!mounted) return;
    setState(() {
      rememberMe = preference;
    });
    _rememberMeFieldKey.currentState?.didChange(preference);
  }

  @override
  void dispose() {
    _jidTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _passwordTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _password2TextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _captchaTextController
      ..removeListener(_handleFieldProgressChanged)
      ..dispose();
    _captchaRetryTimer?.cancel();
    _signupRebuildTimer?.cancel();
    _stopAvatarCarousel();
    _avatarPreviewNotifier.dispose();
    widget.onLoadingChanged?.call(false);
    _lastReportedLoading = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_captchaSrcInitialized) {
      return;
    }
    _lastCaptchaServer = context.read<AuthenticationCubit>().state.server;
    _captchaSrc = _loadCaptchaSrc();
    _captchaSrcInitialized = true;
    if (!_avatarInitialized) {
      _avatarInitialized = true;
      _avatarBackground = context.colorScheme.accent;
      unawaited(_startAvatarCarousel());
    }
  }

  void _handleFieldProgressChanged() {
    if (!mounted) return;
    final password = _passwordTextController.text;
    if (_lastPasswordValue != password) {
      _lastPasswordValue = password;
      _showAllowInsecureError = false;
      _showBreachedError = false;
      if (_passwordBreached && _lastBreachedPassword != password) {
        _passwordBreached = false;
        _lastBreachedPassword = null;
      }
    }
    if (_insecurePasswordReason == null && allowInsecurePassword) {
      allowInsecurePassword = false;
      _allowInsecureResetTick++;
    }
    setState(() {});
  }

  void _updateAvatarPreview(Uint8List? bytes) {
    if (_avatarPreviewNotifier.value == bytes) {
      return;
    }
    _avatarPreviewNotifier.value = bytes;
  }

  double _measureTextHeight(
    BuildContext context, {
    required String text,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    return painter.height;
  }

  void _notifyLoadingChanged(bool loading) {
    if (_lastReportedLoading == loading) {
      return;
    }
    _lastReportedLoading = loading;
    final callback = widget.onLoadingChanged;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback(loading);
    });
  }

  void _onPressed(BuildContext context) async {
    if (_avatarProcessing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final splitSrc = (await _captchaSrc).split('/');
    if (!context.mounted || _formKeys.last.currentState?.validate() == false) {
      return;
    }
    widget.onSubmitStart?.call();
    await context.read<AuthenticationCubit>().signup(
          username: _jidTextController.value.text,
          password: _passwordTextController.value.text,
          confirmPassword: _password2TextController.value.text,
          captchaID: splitSrc[splitSrc.indexOf('captcha') + 1],
          captcha: _captchaTextController.value.text,
          rememberMe: rememberMe,
          avatar: _signupAvatar,
        );
  }

  Future<String> _loadCaptchaSrc() async {
    late final XmlDocument document;
    try {
      final registrationUrl =
          context.read<AuthenticationCubit>().registrationUrl;
      _lastCaptchaServer = context.read<AuthenticationCubit>().state.server;
      final response = await http.get(registrationUrl);
      if (response.statusCode != 200) return '';
      document = XmlDocument.parse(response.body);
    } on http.ClientException catch (_) {
      return '';
    } on XmlParserException catch (_) {
      return '';
    } on XmlTagException catch (_) {
      return '';
    } on Exception catch (_) {
      return '';
    }
    return document.findAllElements('img').firstOrNull?.getAttribute('src') ??
        '';
  }

  void _reloadCaptcha({bool resetFirstLoad = false}) {
    _captchaRetryTimer?.cancel();
    _captchaRetryTimer = null;
    if (resetFirstLoad) {
      _captchaHasLoadedOnce = false;
    }
    _captchaTextController.clear();
    if (!mounted) return;
    setState(() {
      _captchaSrc = _loadCaptchaSrc();
    });
  }

  void _scheduleInitialCaptchaRetry() {
    if (_captchaHasLoadedOnce || _captchaRetryTimer != null) {
      return;
    }
    _captchaRetryTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _captchaHasLoadedOnce) {
        _captchaRetryTimer?.cancel();
        _captchaRetryTimer = null;
        return;
      }
      _captchaRetryTimer = null;
      _reloadCaptcha(resetFirstLoad: true);
    });
  }

  AvatarTemplate? get _activeAvatarTemplate =>
      _selectedTemplate ?? _currentCarouselAvatar?.template;

  _AvatarEditorMode get _avatarEditorMode {
    final template = _activeAvatarTemplate;
    final category = template?.category ?? _currentCarouselAvatar?.category;
    if (category == null) {
      return _signupSourceBytes != null && _currentCarouselAvatar == null
          ? _AvatarEditorMode.cropOnly
          : _AvatarEditorMode.none;
    }
    if (category == AvatarTemplateCategory.abstract) {
      return _AvatarEditorMode.none;
    }
    return _AvatarEditorMode.colorOnly;
  }

  bool get _needsBackgroundPicker =>
      _avatarEditorMode == _AvatarEditorMode.colorOnly;

  bool get _hasUserSelectedAvatar => _signupAvatar != null;

  Future<GeneratedAvatar?> _generateAvatarFromTemplate({
    required AvatarTemplate template,
    required Color background,
    required ShadColorScheme colors,
  }) async {
    try {
      final generated = await template.generator(background, colors);
      if (generated.bytes.isEmpty) {
        return null;
      }
      return generated;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _buildTemplatePreview({
    required GeneratedAvatar generated,
    required AvatarTemplate template,
    required Color background,
  }) async {
    final useInset = template.category != AvatarTemplateCategory.abstract;
    final insetFraction = useInset
        ? (template.hasAlphaBackground
            ? _avatarTransparentInsetFraction
            : _avatarInsetFraction)
        : 0.0;
    final shouldInset = insetFraction > 0;
    final needsPaddingSample =
        useInset && !template.hasAlphaBackground && background.a == 0;
    img.Image? decoded;
    Color paddingColor = background;
    if (needsPaddingSample) {
      decoded = await decodeImageBytes(generated.bytes);
      if (decoded == null) return null;
      paddingColor = _paddingColorForTemplate(
        image: decoded,
        template: template,
        fallback: background,
      );
    }
    final hasAlpha = template.hasAlphaBackground || generated.hasAlpha;
    final shouldFlatten = shouldInset || (paddingColor.a > 0 && hasAlpha);
    final cropSide = math.min(
      (decoded?.width ?? generated.width).toDouble(),
      (decoded?.height ?? generated.height).toDouble(),
    );
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: generated.bytes,
        cropLeft: 0,
        cropTop: 0,
        cropSide: cropSide,
        targetSize: _avatarTargetSize,
        maxBytes: _avatarMaxBytes,
        insetFraction: insetFraction,
        shouldInset: shouldInset,
        backgroundColor: paddingColor.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: _avatarMinJpegQuality,
        qualityStep: _avatarQualityStep,
      ),
    );
    return processed.bytes;
  }

  Color _paddingColorForTemplate({
    required img.Image image,
    AvatarTemplate? template,
    required Color fallback,
  }) {
    if (template == null ||
        template.category == AvatarTemplateCategory.abstract ||
        image.width <= 0 ||
        image.height <= 0) {
      return fallback;
    }
    if (template.hasAlphaBackground || fallback.a > 0) {
      return fallback;
    }
    final samples = [
      image.getPixel(0, 0),
      image.getPixel(image.width - 1, 0),
      image.getPixel(0, image.height - 1),
      image.getPixel(image.width - 1, image.height - 1),
    ];
    final count = samples.length;
    final r = samples.fold<int>(0, (sum, pixel) => sum + (pixel.r as int));
    final g = samples.fold<int>(0, (sum, pixel) => sum + (pixel.g as int));
    final b = samples.fold<int>(0, (sum, pixel) => sum + (pixel.b as int));
    final a = samples.fold<int>(0, (sum, pixel) => sum + (pixel.a as int));
    return Color.fromARGB(
      a ~/ count,
      r ~/ count,
      g ~/ count,
      b ~/ count,
    );
  }

  Future<
      ({
        GeneratedAvatar generated,
        AvatarTemplate template,
        Color background
      })?> _loadAnyTemplateAvatar({
    AvatarTemplate? preferredTemplate,
    int maxAttempts = 6,
  }) async {
    final colors = context.colorScheme;
    final tried = <String>{};
    AvatarTemplate? template = preferredTemplate;
    while (tried.length < maxAttempts) {
      template ??= _pickCarouselTemplate();
      if (template == null) {
        break;
      }
      if (!tried.add(template.id)) {
        template = _pickCarouselTemplate();
        continue;
      }
      final background = template.hasAlphaBackground
          ? _randomAvatarBackgroundColor(colors)
          : _avatarBackground;
      final generated = await _generateAvatarFromTemplate(
        template: template,
        background: background,
        colors: colors,
      );
      if (generated != null) {
        return (
          generated: generated,
          template: template,
          background: background
        );
      }
      template = null;
    }
    return null;
  }

  GeneratedAvatar _fallbackGeneratedAvatar({
    Color? background,
    Color? accent,
  }) {
    const size = _avatarTargetSize;
    final colors = context.colorScheme;
    final base = background ?? _avatarBackground;
    final safeBase = base == Colors.transparent ? colors.accent : base;
    final accentColor = accent ?? colors.primary;
    final image = img.Image(width: size, height: size, numChannels: 4);
    img.fill(image, color: _imgColor(safeBase));
    img.fillRect(
      image,
      x1: size ~/ 6,
      y1: size ~/ 6,
      x2: size - size ~/ 6 - 1,
      y2: size - size ~/ 6 - 1,
      color: _imgColor(accentColor),
    );
    final bytes = Uint8List.fromList(img.encodePng(image, level: 1));
    return GeneratedAvatar(
      bytes: bytes,
      mimeType: 'image/png',
      width: size,
      height: size,
      hasAlpha: false,
    );
  }

  img.Color _imgColor(Color color) {
    final argb = color.toARGB32();
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }

  Future<void> _startAvatarCarousel() async {
    if (_hasUserSelectedAvatar ||
        _avatarProcessing ||
        _avatarCarouselTimer != null ||
        _avatarCarouselPrefilling) {
      return;
    }
    await _prefillCarousel(
      targetSize: _avatarCarouselInitialBuffer,
      preferAbstract: !_nonAbstractAvatarsReady,
    );
    if (!mounted || _hasUserSelectedAvatar) {
      return;
    }
    final showedInitial = _showNextCarouselAvatar(allowFallback: false);
    if (!showedInitial && mounted && !_hasUserSelectedAvatar) {
      _showNextCarouselAvatar();
    }
    _avatarCarouselTimer = Timer.periodic(
      _avatarCarouselInterval,
      (_) {
        _showNextCarouselAvatar(allowFallback: false);
        unawaited(
          _prefillCarousel(
            targetSize: _avatarCarouselSustainBuffer,
            preferAbstract: !_nonAbstractAvatarsReady,
          ),
        );
      },
    );
  }

  void _stopAvatarCarousel() {
    _avatarCarouselTimer?.cancel();
    _avatarCarouselTimer = null;
  }

  void _resumeAvatarCarouselIfNeeded() {
    if (_hasUserSelectedAvatar ||
        _avatarProcessing ||
        !_avatarInitialized ||
        _avatarCarouselTimer != null) {
      return;
    }
    unawaited(_startAvatarCarousel());
  }

  bool _showNextCarouselAvatar({bool allowFallback = true}) {
    if (!mounted || _avatarProcessing || _hasUserSelectedAvatar) {
      return false;
    }
    if (_carouselBuffer.isEmpty) {
      if (!allowFallback) {
        return false;
      }
      final fallbackBackground = _avatarBackground == Colors.transparent
          ? context.colorScheme.accent
          : _avatarBackground;
      final fallback = _fallbackGeneratedAvatar(
        background: fallbackBackground,
      );
      setState(() {
        _currentCarouselAvatar = _CarouselAvatar(
          bytes: fallback.bytes,
          sourceBytes: fallback.bytes,
          template: null,
          category: AvatarTemplateCategory.abstract,
          background: fallbackBackground,
        );
        _selectedTemplate = null;
        _carouselAvatarPreview = fallback.bytes;
        _avatarBackground = _currentCarouselAvatar!.background;
        _avatarError = null;
      });
      _updateAvatarPreview(fallback.bytes);
      return true;
    }
    final entry = _carouselBuffer.removeAt(0);
    if (!_nonAbstractAvatarsReady &&
        entry.category != AvatarTemplateCategory.abstract) {
      _nonAbstractAvatarsReady = true;
    }
    setState(() {
      _currentCarouselAvatar = entry;
      _selectedTemplate = entry.template;
      _avatarBackground = entry.background;
      _carouselAvatarPreview = entry.bytes;
      _avatarError = null;
    });
    _updateAvatarPreview(entry.bytes);
    return true;
  }

  AvatarTemplate? _pickCarouselTemplate() {
    final hasAbstract = _abstractAvatarTemplates.isNotEmpty;
    final hasOther = _nonAbstractAvatarTemplates.isNotEmpty;
    if (!hasAbstract && !hasOther) {
      return null;
    }
    if (!hasOther) {
      return _pickFromPool(
        _abstractAvatarTemplates,
        bag: _abstractCarouselBag,
      );
    }
    if (!hasAbstract) {
      return _pickFromPool(
        _nonAbstractAvatarTemplates,
        bag: _nonAbstractCarouselBag,
      );
    }
    final useAbstract = _random.nextBool();
    return _pickFromPool(
      useAbstract ? _abstractAvatarTemplates : _nonAbstractAvatarTemplates,
      bag: useAbstract ? _abstractCarouselBag : _nonAbstractCarouselBag,
    );
  }

  AvatarTemplate? _pickFromPool(
    List<AvatarTemplate> pool, {
    required List<AvatarTemplate> bag,
  }) {
    if (pool.isEmpty) return null;
    if (bag.isEmpty) {
      bag.addAll(pool);
      bag.shuffle(_random);
    }
    AvatarTemplate? selection;
    final recycled = <AvatarTemplate>[];
    while (bag.isNotEmpty) {
      final candidate = bag.removeAt(0);
      if (_recentCarouselAvatarIds.contains(candidate.id)) {
        recycled.add(candidate);
        continue;
      }
      selection = candidate;
      break;
    }
    bag.addAll(recycled);
    selection ??=
        bag.isNotEmpty ? bag.removeAt(0) : pool[_random.nextInt(pool.length)];
    return selection;
  }

  void _pushRecentCarouselAvatar(String id) {
    _recentCarouselAvatarIds.add(id);
    if (_recentCarouselAvatarIds.length > _avatarCarouselHistoryLimit) {
      _recentCarouselAvatarIds.removeAt(0);
    }
  }

  _AvatarSelection? _pickAvatarSelection() {
    final template = _pickCarouselTemplate();
    if (template == null) return null;
    final colors = context.colorScheme;
    final background = _randomAvatarBackgroundColor(colors);
    return _AvatarSelection(template: template, background: background);
  }

  Color _randomAvatarBackgroundColor(ShadColorScheme colors) {
    final hue = _random.nextDouble() * 360.0;
    final saturation = 0.75 + _random.nextDouble() * 0.25;
    final lightness = 0.38 + _random.nextDouble() * 0.17;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Future<bool> _prefillCarousel({
    int targetSize = 2,
    bool preferAbstract = false,
  }) async {
    if (_avatarCarouselPrefilling ||
        !mounted ||
        _hasUserSelectedAvatar ||
        _avatarProcessing) {
      return _carouselBuffer.isNotEmpty;
    }
    _avatarCarouselPrefilling = true;
    final colors = context.colorScheme;
    if (preferAbstract &&
        !_nonAbstractAvatarsReady &&
        !_warmingNonAbstractAvatars &&
        _nonAbstractAvatarTemplates.isNotEmpty) {
      _warmingNonAbstractAvatars = true;
      unawaited(_warmFirstNonAbstractAvatar(colors));
    }
    var added = 0;
    var attempts = 0;
    const maxAttempts = 6;
    try {
      while (mounted &&
          !_hasUserSelectedAvatar &&
          _carouselBuffer.length < targetSize &&
          attempts < maxAttempts) {
        final useAbstractOnly = preferAbstract &&
            !_nonAbstractAvatarsReady &&
            _abstractAvatarTemplates.isNotEmpty;
        AvatarTemplate? template = useAbstractOnly
            ? _pickFromPool(
                _abstractAvatarTemplates,
                bag: _abstractCarouselBag,
              )
            : null;
        template ??= _pickCarouselTemplate();
        if (template == null) break;
        attempts++;
        _pushRecentCarouselAvatar(template.id);
        final background = template.hasAlphaBackground
            ? _randomAvatarBackgroundColor(colors)
            : _avatarBackground;
        final generated = await _generateAvatarFromTemplate(
          template: template,
          background: background,
          colors: colors,
        );
        if (generated == null) {
          continue;
        }
        final previewBytes = await _buildTemplatePreview(
              generated: generated,
              template: template,
              background: background,
            ) ??
            generated.bytes;
        _carouselBuffer.add(
          _CarouselAvatar(
            bytes: previewBytes,
            sourceBytes: generated.bytes,
            template: template,
            category: template.category,
            background: background,
          ),
        );
        if (!_nonAbstractAvatarsReady &&
            template.category != AvatarTemplateCategory.abstract) {
          _nonAbstractAvatarsReady = true;
        }
        added++;
      }
      if (added == 0 &&
          _carouselBuffer.isEmpty &&
          mounted &&
          !_hasUserSelectedAvatar) {
        final fallbackBackground = _avatarBackground == Colors.transparent
            ? colors.accent
            : _avatarBackground;
        final fallback = _fallbackGeneratedAvatar(
          background: fallbackBackground,
        );
        _carouselBuffer.add(
          _CarouselAvatar(
            bytes: fallback.bytes,
            sourceBytes: fallback.bytes,
            template: null,
            category: AvatarTemplateCategory.abstract,
            background: fallbackBackground,
          ),
        );
        return true;
      }
    } catch (_) {
      // Ignore generation errors; fallback handled below.
    } finally {
      _avatarCarouselPrefilling = false;
    }
    return added > 0;
  }

  Future<void> _warmFirstNonAbstractAvatar(ShadColorScheme colors) async {
    try {
      final template = _pickFromPool(
        _nonAbstractAvatarTemplates,
        bag: _nonAbstractCarouselBag,
      );
      if (template == null) return;
      _pushRecentCarouselAvatar(template.id);
      final background = template.hasAlphaBackground
          ? _randomAvatarBackgroundColor(colors)
          : _avatarBackground;
      final generated = await _generateAvatarFromTemplate(
        template: template,
        background: background,
        colors: colors,
      );
      if (generated == null || !mounted) return;
      final previewBytes = await _buildTemplatePreview(
            generated: generated,
            template: template,
            background: background,
          ) ??
          generated.bytes;
      if (!mounted) return;
      _nonAbstractAvatarsReady = true;
      _carouselBuffer.add(
        _CarouselAvatar(
          bytes: previewBytes,
          sourceBytes: generated.bytes,
          template: template,
          category: template.category,
          background: background,
        ),
      );
    } catch (_) {
      // Ignore warmup failures; fallback handled by carousel buffer.
    } finally {
      _warmingNonAbstractAvatars = false;
    }
  }

  Future<void> _selectTemplate(
    AvatarTemplate template, {
    Color? background,
  }) async {
    if (_avatarProcessing) return;
    if (!mounted) return;
    if (!_nonAbstractAvatarsReady &&
        template.category != AvatarTemplateCategory.abstract) {
      _nonAbstractAvatarsReady = true;
    }
    _stopAvatarCarousel();
    _carouselBuffer.clear();
    setState(() {
      _avatarProcessing = true;
      _avatarError = null;
      _carouselAvatarPreview = null;
      _currentCarouselAvatar = null;
    });
    final effectiveBackground = background ?? _avatarBackground;
    final colors = context.colorScheme;
    try {
      GeneratedAvatar? generated;
      Color usedBackground = effectiveBackground;
      if (background != null) {
        generated = await _generateAvatarFromTemplate(
          template: template,
          background: effectiveBackground,
          colors: colors,
        );
        generated ??= _fallbackGeneratedAvatar(background: effectiveBackground);
      } else {
        final result = await _loadAnyTemplateAvatar(
              preferredTemplate: template,
              maxAttempts: 6,
            ) ??
            (
              generated:
                  _fallbackGeneratedAvatar(background: effectiveBackground),
              template: template,
              background: effectiveBackground,
            );
        generated = result.generated;
        usedBackground = result.background;
      }
      final decoded = await decodeImageBytes(generated.bytes);
      if (decoded == null) {
        final fallback =
            _fallbackGeneratedAvatar(background: effectiveBackground);
        final fallbackDecoded = await decodeImageBytes(fallback.bytes);
        if (fallbackDecoded == null || !mounted) {
          return;
        }
        _avatarBackground = effectiveBackground;
        _signupSourceImage = fallbackDecoded;
        _signupSourceBytes = fallback.bytes;
        _signupImageWidth = fallbackDecoded.width.toDouble();
        _signupImageHeight = fallbackDecoded.height.toDouble();
        _signupCropRect = _initialSignupCropRect(
          fallbackDecoded,
          templateCategory: template.category,
        );
        _selectedTemplate = template;
        await _rebuildSignupAvatar();
        return;
      }
      _avatarBackground =
          template.hasAlphaBackground ? usedBackground : _avatarBackground;
      _pushRecentCarouselAvatar(template.id);
      _signupSourceImage = decoded;
      _signupSourceBytes = generated.bytes;
      _signupImageWidth = decoded.width.toDouble();
      _signupImageHeight = decoded.height.toDouble();
      _signupCropRect = _initialSignupCropRect(
        decoded,
        templateCategory: template.category,
      );
      _selectedTemplate = template;
      await _rebuildSignupAvatar();
    } catch (_) {
      final fallback =
          _fallbackGeneratedAvatar(background: effectiveBackground);
      final decoded = await decodeImageBytes(fallback.bytes);
      if (!mounted || decoded == null) {
        return;
      }
      _avatarBackground = effectiveBackground;
      _pushRecentCarouselAvatar(template.id);
      _signupSourceImage = decoded;
      _signupSourceBytes = fallback.bytes;
      _signupImageWidth = decoded.width.toDouble();
      _signupImageHeight = decoded.height.toDouble();
      _signupCropRect = _initialSignupCropRect(
        decoded,
        templateCategory: template.category,
      );
      _selectedTemplate = template;
      await _rebuildSignupAvatar();
    }
  }

  Future<void> _pickAvatarFromFiles() async {
    if (!mounted) return;
    _stopAvatarCarousel();
    final l10n = context.l10n;
    setState(() {
      _avatarProcessing = true;
      _avatarError = null;
      _carouselAvatarPreview = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() {
          _avatarProcessing = false;
        });
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      final file = result.files.first;
      final bytes = await _loadPickedFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _avatarProcessing = false;
          _avatarError = l10n.signupAvatarReadError;
        });
        _resumeAvatarCarouselIfNeeded();
        return;
      }
      await _applyAvatarFromBytes(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _avatarProcessing = false;
        _avatarError = l10n.signupAvatarOpenError;
      });
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<Uint8List?> _loadPickedFileBytes(PlatformFile file) async {
    if (file.bytes?.isNotEmpty == true) {
      return file.bytes!;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final data = builder.takeBytes();
    return data.isEmpty ? null : data;
  }

  Future<void> _applyAvatarFromBytes(Uint8List bytes) async {
    _stopAvatarCarousel();
    final l10n = context.l10n;
    final decoded = await decodeImageBytes(bytes);
    if (decoded == null) {
      if (!mounted) return;
      setState(() {
        _avatarProcessing = false;
        _avatarError = l10n.signupAvatarInvalidImage;
      });
      _resumeAvatarCarouselIfNeeded();
      return;
    }
    _signupSourceImage = decoded;
    _signupSourceBytes = bytes;
    _signupImageWidth = decoded.width.toDouble();
    _signupImageHeight = decoded.height.toDouble();
    _signupCropRect = _initialSignupCropRect(
      decoded,
      isUserUpload: true,
    );
    _currentCarouselAvatar = null;
    _avatarBackground = Colors.transparent;
    _selectedTemplate = null;
    // picker always available; alpha tracking no longer needed
    _avatarProcessing = true;
    await _rebuildSignupAvatar();
  }

  Rect _initialSignupCropRect(
    img.Image image, {
    AvatarTemplateCategory? templateCategory,
    bool isUserUpload = false,
  }) {
    if (!isUserUpload) {
      final category = templateCategory ??
          _activeAvatarTemplate?.category ??
          _currentCarouselAvatar?.category;
      if (category != null) {
        return Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
      }
    }
    return AvatarCropper.fallbackCropRect(
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      minCropSide: AvatarEditorCubit.minCropSide,
    );
  }

  Rect _constrainSignupRect(Rect rect, img.Image image) {
    final availableSide =
        math.min(image.width.toDouble(), image.height.toDouble());
    final desiredSide = math
        .min(rect.width, rect.height)
        .clamp(AvatarEditorCubit.minCropSide, availableSide);
    final maxLeft = image.width - desiredSide;
    final maxTop = image.height - desiredSide;
    final left = rect.left.clamp(0.0, maxLeft);
    final top = rect.top.clamp(0.0, maxTop);
    return Rect.fromLTWH(left, top, desiredSide, desiredSide);
  }

  void _updateSignupCropRect(Rect rect) {
    final image = _signupSourceImage;
    if (image == null) return;
    final constrained = _constrainSignupRect(rect, image);
    if (_signupCropRect == constrained) return;
    setState(() {
      _signupCropRect = constrained;
      _avatarProcessing = true;
    });
    _scheduleSignupRebuild();
  }

  void _resetSignupCrop() {
    final image = _signupSourceImage;
    if (image == null) return;
    setState(() {
      _signupCropRect = _initialSignupCropRect(
        image,
        isUserUpload: _avatarEditorMode == _AvatarEditorMode.cropOnly,
      );
      _avatarProcessing = true;
    });
    _scheduleSignupRebuild();
  }

  void _updateAvatarBackground(Color color) {
    if (_avatarBackground == color) return;
    final template = _selectedTemplate ?? _currentCarouselAvatar?.template;
    setState(() {
      _avatarBackground = color;
    });
    if (template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        !_avatarProcessing) {
      unawaited(_selectTemplate(template, background: color));
      return;
    }
    setState(() {
      _avatarProcessing = true;
    });
    _scheduleSignupRebuild();
  }

  void _scheduleSignupRebuild() {
    _signupRebuildTimer?.cancel();
    _signupRebuildTimer = Timer(
      const Duration(milliseconds: 140),
      () => unawaited(_rebuildSignupAvatar()),
    );
  }

  Future<void> _rebuildSignupAvatar() async {
    _signupRebuildTimer?.cancel();
    final source = _signupSourceImage;
    if (source == null) {
      if (!mounted) return;
      setState(() {
        _avatarProcessing = false;
      });
      _resumeAvatarCarouselIfNeeded();
      return;
    }
    await Future<void>.delayed(Duration.zero);
    try {
      final payload = await _processSignupImage(source);
      if (!mounted) return;
      setState(() {
        _signupAvatar = payload;
        _signupAvatarPreview = payload.bytes;
        _carouselAvatarPreview = null;
        _avatarProcessing = false;
        _avatarError = null;
      });
      _updateAvatarPreview(payload.bytes);
      _stopAvatarCarousel();
    } catch (error) {
      if (!mounted) return;
      final message = error is _AvatarSizeException
          ? context.l10n.signupAvatarSizeError(
              (_avatarMaxBytes / 1024).round(),
            )
          : context.l10n.signupAvatarProcessError;
      setState(() {
        _avatarProcessing = false;
        _avatarError = message;
      });
      _resumeAvatarCarouselIfNeeded();
    }
  }

  Future<AvatarUploadPayload> _processSignupImage(img.Image image) async {
    final sourceBytes = _signupSourceBytes;
    if (sourceBytes == null || sourceBytes.isEmpty) {
      throw const _AvatarSizeException();
    }
    final templateCategory =
        _activeAvatarTemplate?.category ?? _currentCarouselAvatar?.category;
    final baseCrop = _signupCropRect ??
        _initialSignupCropRect(
          image,
          templateCategory: templateCategory,
          isUserUpload: _avatarEditorMode == _AvatarEditorMode.cropOnly,
        );
    final safeCrop = _constrainSignupRect(baseCrop, image);
    final template = _activeAvatarTemplate;
    final useTemplateInset = template != null &&
        template.category != AvatarTemplateCategory.abstract;
    final padAlphaTemplate =
        template?.hasAlphaBackground == true && useTemplateInset;
    final insetFraction = useTemplateInset
        ? (padAlphaTemplate
            ? _avatarTransparentInsetFraction
            : _avatarInsetFraction)
        : 0.0;
    final shouldInset = insetFraction > 0;
    final hasAlpha = image.hasAlpha || image.numChannels == 4;
    final paddingColor = _paddingColorForTemplate(
      image: image,
      template: template,
      fallback: _avatarBackground,
    );
    final shouldFlatten = shouldInset || (paddingColor.a > 0 && hasAlpha);
    final processed = await processAvatar(
      AvatarProcessRequest(
        bytes: sourceBytes,
        cropLeft: safeCrop.left,
        cropTop: safeCrop.top,
        cropSide: safeCrop.width,
        targetSize: _avatarTargetSize,
        maxBytes: _avatarMaxBytes,
        insetFraction: insetFraction,
        shouldInset: shouldInset,
        backgroundColor: paddingColor.toARGB32(),
        flattenBackground: shouldFlatten,
        minJpegQuality: _avatarMinJpegQuality,
        qualityStep: _avatarQualityStep,
      ),
    );
    final hash = sha1.convert(processed.bytes).toString();
    return AvatarUploadPayload(
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      hash: hash,
    );
  }

  Future<void> _openAvatarMenu() async {
    if (_avatarProcessing) return;
    final currentCarousel = _currentCarouselAvatar;
    final nextTemplate = _selectedTemplate ?? currentCarousel?.template;
    final nextBackground = currentCarousel?.background ?? _avatarBackground;
    _updateAvatarPreview(
      _signupAvatarPreview ?? _carouselAvatarPreview ?? currentCarousel?.bytes,
    );
    final templateCategory =
        _activeAvatarTemplate?.category ?? _currentCarouselAvatar?.category;
    final editorBytes = _signupSourceBytes ??
        currentCarousel?.sourceBytes ??
        _signupAvatarPreview ??
        _carouselAvatarPreview ??
        currentCarousel?.bytes;
    if (_signupSourceImage == null && editorBytes != null) {
      final decoded = await decodeImageBytes(editorBytes);
      if (decoded != null && mounted) {
        setState(() {
          _signupSourceImage = decoded;
          _signupSourceBytes = editorBytes;
          _signupImageWidth = decoded.width.toDouble();
          _signupImageHeight = decoded.height.toDouble();
          _signupCropRect ??= _initialSignupCropRect(
            decoded,
            templateCategory: templateCategory,
            isUserUpload: _avatarEditorMode == _AvatarEditorMode.cropOnly,
          );
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _selectedTemplate = nextTemplate;
      _avatarBackground = nextBackground;
      _showAvatarEditor = true;
    });
  }

  void _markCaptchaLoaded() {
    if (_captchaHasLoadedOnce) return;
    _captchaRetryTimer?.cancel();
    _captchaRetryTimer = null;
    if (!mounted) return;
    setState(() {
      _captchaHasLoadedOnce = true;
    });
  }

  static const captchaSize = Size(180, 70);
  static const _progressSegmentCount = 3;

  String get _currentStepLabel {
    final l10n = context.l10n;
    switch (_currentIndex) {
      case 0:
        return l10n.signupStepUsername;
      case 1:
        return l10n.signupStepPassword;
      case 2:
        return l10n.signupStepCaptcha;
      default:
        return l10n.signupStepSetup;
    }
  }

  double get _passwordEntropyBits {
    final password = _passwordTextController.text;
    if (password.isEmpty) {
      return 0;
    }
    final pool = _estimateCharacterPool(password);
    return password.length * (math.log(pool) / math.ln2);
  }

  _PasswordStrengthLevel get _passwordStrengthLevel {
    if (_passwordTextController.text.isEmpty) {
      return _PasswordStrengthLevel.empty;
    }
    final entropy = _passwordEntropyBits;
    if (entropy < _weakEntropyThreshold) {
      return _PasswordStrengthLevel.weak;
    }
    if (entropy < _strongEntropyThreshold) {
      return _PasswordStrengthLevel.medium;
    }
    return _PasswordStrengthLevel.stronger;
  }

  _InsecurePasswordReason? get _insecurePasswordReason {
    if (_passwordBreached) {
      return _InsecurePasswordReason.breached;
    }
    if (_passwordStrengthLevel == _PasswordStrengthLevel.weak) {
      return _InsecurePasswordReason.weak;
    }
    return null;
  }

  int _estimateCharacterPool(String password) {
    var pool = 0;
    if (_digitCharacters.hasMatch(password)) {
      pool += 10;
    }
    if (_lowercaseCharacters.hasMatch(password)) {
      pool += 26;
    }
    if (_uppercaseCharacters.hasMatch(password)) {
      pool += 26;
    }
    if (_symbolCharacters.hasMatch(password)) {
      pool += 33;
    }
    return pool == 0 ? 1 : pool;
  }

  bool get _isUsernameValid =>
      _usernamePattern.hasMatch(_jidTextController.text);

  bool get _passwordWithinBounds =>
      _passwordTextController.text.isNotEmpty &&
      _passwordTextController.text.length <= passwordMaxLength;

  bool get _passwordsMatch =>
      _password2TextController.text.isNotEmpty &&
      _password2TextController.text == _passwordTextController.text;

  bool get _arePasswordsValid => _passwordWithinBounds && _passwordsMatch;

  bool get _captchaComplete => _captchaTextController.text.trim().isNotEmpty;

  bool get _hasStartedPasswordConfirmation =>
      _passwordTextController.text.isNotEmpty &&
      _password2TextController.text.isNotEmpty;

  _InsecurePasswordReason? get _visibleInsecurePasswordReason {
    final reason = _insecurePasswordReason;
    if (reason == _InsecurePasswordReason.weak &&
        !_hasStartedPasswordConfirmation) {
      return null;
    }
    return reason;
  }

  int get _completedStepCount => [
        _isUsernameValid,
        _arePasswordsValid,
        _captchaComplete,
      ].where((complete) => complete).length;

  double get _progressValue => _completedStepCount / _progressSegmentCount;

  Future<void> _handleContinuePressed(BuildContext context) async {
    if (_avatarProcessing) return;
    final formState = _formKeys[_currentIndex].currentState;
    if (formState?.validate() == false) {
      return;
    }
    if (_currentIndex == 1) {
      await _advanceFromPasswordStep(context);
      return;
    }
    _goToNextSignupStep();
  }

  Future<void> _advanceFromPasswordStep(BuildContext context) async {
    final password = _passwordTextController.text;
    final isWeak = _passwordStrengthLevel == _PasswordStrengthLevel.weak;
    if ((isWeak || _passwordBreached) && !allowInsecurePassword) {
      if (!mounted) return;
      setState(() {
        _showAllowInsecureError = true;
        _showBreachedError = _passwordBreached;
      });
      return;
    }

    if (allowInsecurePassword) {
      _goToNextSignupStep();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _pwnedCheckInProgress = true;
    });
    final notPwned = await context
        .read<AuthenticationCubit>()
        .checkNotPwned(password: password);
    if (!mounted) return;
    setState(() {
      _pwnedCheckInProgress = false;
    });

    if (!notPwned) {
      setState(() {
        _passwordBreached = true;
        _lastBreachedPassword = password;
        _showBreachedError = true;
        _showAllowInsecureError = true;
      });
      _formKeys[1].currentState?.validate();
      return;
    }

    setState(() {
      _passwordBreached = false;
      _lastBreachedPassword = null;
    });
    _goToNextSignupStep();
  }

  void _goToNextSignupStep() {
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _errorText = null;
      _showAllowInsecureError = false;
      _showBreachedError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<AuthenticationCubit, AuthenticationState>(
      // listenWhen: (previous, current) => current is AuthenticationSignupFailure && previous is!AuthenticationSignupFailure,
      listener: (context, state) {
        if (state is AuthenticationSignupFailure) {
          _reloadCaptcha(resetFirstLoad: true);
          setState(() {
            _errorText = state.errorText;
          });
        }
      },
      builder: (context, state) {
        if (_lastCaptchaServer != state.server) {
          _lastCaptchaServer = state.server;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _reloadCaptcha(resetFirstLoad: true);
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _resumeAvatarCarouselIfNeeded();
          if (_carouselAvatarPreview == null) {
            unawaited(
              _prefillCarousel(
                targetSize: _avatarCarouselSustainBuffer,
              ).then((_) {
                if (!mounted || _hasUserSelectedAvatar) return;
                final displayed = _showNextCarouselAvatar(allowFallback: false);
                if (!displayed &&
                    mounted &&
                    !_hasUserSelectedAvatar &&
                    _carouselBuffer.isEmpty) {
                  _showNextCarouselAvatar();
                }
              }),
            );
          }
        });
        final bool onSubmitStep = _currentIndex == _formKeys.length - 1;
        final bool signupFlowActive =
            state is AuthenticationSignUpInProgress && onSubmitStep;
        final bool latchActive = (_lastReportedLoading ?? false) &&
            (state is AuthenticationLogInInProgress ||
                state is AuthenticationComplete);
        final loading = signupFlowActive || latchActive;
        _notifyLoadingChanged(loading);
        final cleanupBlocked =
            state is AuthenticationSignupFailure && state.isCleanupBlocked;
        const horizontalPadding = EdgeInsets.symmetric(horizontal: 8.0);
        const errorPadding = EdgeInsets.fromLTRB(8, 12, 8, 8);
        const globalErrorPadding = EdgeInsets.fromLTRB(8, 10, 8, 20);
        const fieldSpacing = EdgeInsets.symmetric(vertical: 6.0);
        final l10n = context.l10n;
        final animationDuration =
            context.watch<SettingsCubit>().animationDuration;
        final usernameDescriptionHeight = _measureTextHeight(
          context,
          text: l10n.authUsernameCaseInsensitive,
          style: context.textTheme.small,
        );
        final showGlobalError =
            !_showBreachedError && (_errorText?.trim().isNotEmpty ?? false);
        final displayedAvatarBytes =
            _signupAvatarPreview ?? _carouselAvatarPreview;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: errorPadding,
                  child: _SignupProgressMeter(
                    progressValue: _progressValue,
                    currentStepIndex: _currentIndex,
                    totalSteps: _formKeys.length,
                    currentStepLabel: _currentStepLabel,
                    animationDuration: animationDuration,
                  ),
                ),
                Padding(
                  padding: horizontalPadding,
                  child: Text(
                    l10n.signupTitle,
                    style: context.modalHeaderTextStyle,
                  ),
                ),
                Padding(
                  padding: globalErrorPadding,
                  child: AnimatedSwitcher(
                    duration: animationDuration,
                    child: showGlobalError
                        ? Semantics(
                            liveRegion: true,
                            container: true,
                            label: l10n.signupErrorPrefix(_errorText!),
                            child: Text(
                              _errorText!,
                              key: const ValueKey('signup-global-error-text'),
                              style: TextStyle(
                                color: context.colorScheme.destructive,
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('signup-global-error-empty'),
                          ),
                  ),
                ),
                Padding(
                  padding: horizontalPadding,
                  child: NotificationRequest(
                    notificationService: context.read<NotificationService>(),
                    capability: context.read<Capability>(),
                  ),
                ),
                const SizedBox.square(dimension: 16.0),
                Padding(
                  padding: horizontalPadding,
                  child: AxiAnimatedSize(
                    duration: context.watch<SettingsCubit>().animationDuration,
                    curve: Curves.easeIn,
                    child: AnimatedSwitcher(
                      duration:
                          context.watch<SettingsCubit>().animationDuration,
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder:
                          AnimatedSwitcher.defaultTransitionBuilder,
                      child: [
                        Form(
                          key: _formKeys[0],
                          child: Padding(
                            padding: fieldSpacing,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 10.0,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        -usernameDescriptionHeight,
                                      ),
                                      child: _SignupAvatarSelector(
                                        bytes: displayedAvatarBytes,
                                        username: _jidTextController.text,
                                        processing: _avatarProcessing,
                                        onTap: _openAvatarMenu,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AxiTextFormField(
                                        autocorrect: false,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[a-z0-9._-]'),
                                          ),
                                        ],
                                        keyboardType: TextInputType.name,
                                        description: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0,
                                          ),
                                          child: Text(
                                              l10n.authUsernameCaseInsensitive),
                                        ),
                                        placeholder: Text(l10n.authUsername),
                                        enabled: !loading,
                                        controller: _jidTextController,
                                        trailing: EndpointSuffix(
                                            server: state.server),
                                        validator: (text) {
                                          if (text.isEmpty) {
                                            return l10n.authUsernameRequired;
                                          }
                                          if (!_usernamePattern
                                              .hasMatch(text)) {
                                            return l10n.authUsernameRules;
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_avatarError != null)
                                  Text(
                                    _avatarError!,
                                    style: TextStyle(
                                      color: context.colorScheme.destructive,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (_showAvatarEditor)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: math.min(
                                            MediaQuery.sizeOf(context).width,
                                            960,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            _SignupAvatarEditorPanel(
                                              mode: _avatarEditorMode,
                                              avatarBytesListenable:
                                                  _avatarPreviewNotifier,
                                              sourceBytesProvider: () =>
                                                  _signupSourceBytes ??
                                                  _currentCarouselAvatar
                                                      ?.sourceBytes ??
                                                  _currentCarouselAvatar
                                                      ?.bytes ??
                                                  _carouselAvatarPreview ??
                                                  _signupAvatarPreview,
                                              cropRectProvider: () =>
                                                  _signupCropRect,
                                              imageWidthProvider: () =>
                                                  _signupImageWidth,
                                              imageHeightProvider: () =>
                                                  _signupImageHeight,
                                              backgroundColorProvider: () =>
                                                  _avatarBackground,
                                              onCropChanged:
                                                  _updateSignupCropRect,
                                              onCropReset: _resetSignupCrop,
                                              onBackgroundChanged:
                                                  _needsBackgroundPicker
                                                      ? _updateAvatarBackground
                                                      : null,
                                              onShuffle: () async {
                                                final selection =
                                                    _pickAvatarSelection();
                                                if (selection == null) {
                                                  return;
                                                }
                                                await _selectTemplate(
                                                  selection.template,
                                                  background:
                                                      selection.background,
                                                );
                                              },
                                              onUpload: _pickAvatarFromFiles,
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: AxiIconButton(
                                                iconData: LucideIcons.x,
                                                tooltip: l10n.commonClose,
                                                onPressed: () {
                                                  setState(() {
                                                    _showAvatarEditor = false;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Form(
                          key: _formKeys[1],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: fieldSpacing,
                                child: PasswordInput(
                                  enabled: !loading && !_pwnedCheckInProgress,
                                  controller: _passwordTextController,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: PasswordInput(
                                  enabled: !loading && !_pwnedCheckInProgress,
                                  controller: _password2TextController,
                                  confirmValidator: (text) =>
                                      text != _passwordTextController.text
                                          ? l10n.authPasswordsMismatch
                                          : null,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: _SignupPasswordStrengthMeter(
                                  entropyBits: _passwordEntropyBits,
                                  maxEntropyBits: _maxEntropyBits,
                                  strengthLevel: _passwordStrengthLevel,
                                  showBreachWarning:
                                      _showBreachedError && _passwordBreached,
                                  animationDuration: animationDuration,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: _SignupInsecurePasswordNotice(
                                  reason: _visibleInsecurePasswordReason,
                                  allowInsecurePassword: allowInsecurePassword,
                                  loading: loading,
                                  pwnedCheckInProgress: _pwnedCheckInProgress,
                                  showAllowInsecureError:
                                      _showAllowInsecureError,
                                  animationDuration: animationDuration,
                                  resetTick: _allowInsecureResetTick,
                                  onChanged: (value) {
                                    setState(() {
                                      allowInsecurePassword = value;
                                      if (value) {
                                        _showAllowInsecureError = false;
                                        _showBreachedError = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Form(
                          key: _formKeys[2],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: fieldSpacing +
                                    const EdgeInsets.only(top: 20),
                                child: FutureBuilder<String>(
                                  future: _captchaSrc,
                                  builder: (context, snapshot) {
                                    final hasValidUrl = snapshot.hasData &&
                                        (snapshot.data?.isNotEmpty ?? false);
                                    final encounteredError =
                                        snapshot.hasError ||
                                            (snapshot.hasData && !hasValidUrl);
                                    final persistentError = encounteredError &&
                                        _captchaHasLoadedOnce;
                                    final describingLoading =
                                        (!snapshot.hasData &&
                                                !encounteredError) ||
                                            (encounteredError &&
                                                !_captchaHasLoadedOnce);
                                    Widget captchaSurface;
                                    if (encounteredError) {
                                      if (_captchaHasLoadedOnce) {
                                        captchaSurface =
                                            const _CaptchaErrorMessage();
                                      } else {
                                        _scheduleInitialCaptchaRetry();
                                        captchaSurface =
                                            const _CaptchaSkeleton();
                                      }
                                    } else if (!snapshot.hasData) {
                                      captchaSurface = const _CaptchaSkeleton();
                                    } else {
                                      final captchaUrl = snapshot.requireData;
                                      captchaSurface = _CaptchaImage(
                                        url: captchaUrl,
                                        showErrorMessageOnError:
                                            _captchaHasLoadedOnce,
                                        onLoaded: _markCaptchaLoaded,
                                        onInitialError:
                                            _scheduleInitialCaptchaRetry,
                                      );
                                    }
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Semantics(
                                            label: persistentError
                                                ? l10n.signupCaptchaUnavailable
                                                : l10n.signupCaptchaChallenge,
                                            hint: persistentError
                                                ? l10n.signupCaptchaFailed
                                                : describingLoading
                                                    ? l10n.signupCaptchaLoading
                                                    : l10n
                                                        .signupCaptchaInstructions,
                                            image:
                                                !persistentError && hasValidUrl,
                                            child: persistentError
                                                ? _CaptchaFrame(
                                                    child: captchaSurface,
                                                  )
                                                : ExcludeSemantics(
                                                    child: _CaptchaFrame(
                                                      child: captchaSurface,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Semantics(
                                            button: true,
                                            enabled: !loading,
                                            label: l10n.signupCaptchaReload,
                                            hint: l10n.signupCaptchaReloadHint,
                                            child: AxiIconButton(
                                              iconData: LucideIcons.refreshCw,
                                              tooltip: l10n.signupCaptchaReload,
                                              onPressed: loading
                                                  ? null
                                                  : () => _reloadCaptcha(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: SizedBox(
                                  width: captchaSize.width,
                                  child: AxiTextFormField(
                                    autocorrect: false,
                                    keyboardType: TextInputType.number,
                                    placeholder:
                                        Text(l10n.signupCaptchaPlaceholder),
                                    enabled: !loading,
                                    controller: _captchaTextController,
                                    validator: (text) {
                                      if (text.isEmpty) {
                                        return l10n.signupCaptchaValidation;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: TermsCheckbox(
                                  enabled: !loading,
                                ),
                              ),
                              Padding(
                                padding: fieldSpacing,
                                child: AxiCheckboxFormField(
                                  key: _rememberMeFieldKey,
                                  enabled: !loading,
                                  initialValue: rememberMe,
                                  inputLabel: Text(l10n.authRememberMeLabel),
                                  onChanged: (value) {
                                    setState(() {
                                      rememberMe = value;
                                    });
                                    unawaited(
                                      context
                                          .read<AuthenticationCubit>()
                                          .persistRememberMeChoice(value),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ][_currentIndex],
                    ),
                  ),
                ),
                const SizedBox.square(dimension: 16.0),
                Padding(
                  padding: horizontalPadding,
                  child: Builder(
                    builder: (context) {
                      final isPasswordStep = _currentIndex == 1;
                      final isCheckingPwned =
                          isPasswordStep && _pwnedCheckInProgress;
                      final showBackButton = _currentIndex >= 1;
                      final showNextButton =
                          _currentIndex < _formKeys.length - 1;
                      final showSubmitButton = !showNextButton;

                      final backButton = AxiAnimatedSize(
                        duration: animationDuration,
                        curve: Curves.easeInOut,
                        alignment: Alignment.centerLeft,
                        child: showBackButton
                            ? Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ShadButton.secondary(
                                  enabled: !loading && !isCheckingPwned,
                                  onPressed: () {
                                    setState(() {
                                      _currentIndex--;
                                    });
                                  },
                                  child: Text(l10n.commonBack),
                                ).withTapBounce(
                                  enabled: !loading && !isCheckingPwned,
                                ),
                              )
                            : const SizedBox.shrink(),
                      );

                      final continueButton = showNextButton
                          ? Padding(
                              padding: EdgeInsets.only(
                                right: showSubmitButton ? 8 : 0,
                              ),
                              child: ShadButton(
                                enabled: !loading &&
                                    !isCheckingPwned &&
                                    !_avatarProcessing,
                                onPressed: () async {
                                  await _handleContinuePressed(context);
                                },
                                leading: AnimatedCrossFade(
                                  crossFadeState: isCheckingPwned
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: animationDuration,
                                  firstChild: const SizedBox(),
                                  secondChild: AxiProgressIndicator(
                                    color:
                                        context.colorScheme.primaryForeground,
                                    semanticsLabel: l10n.authPasswordPending,
                                  ),
                                ),
                                trailing: const SizedBox.shrink(),
                                child: Text(l10n.signupContinue),
                              ).withTapBounce(
                                enabled: !loading && !isCheckingPwned,
                              ),
                            )
                          : const SizedBox.shrink();

                      final submitButton = showSubmitButton
                          ? ShadButton(
                              enabled: !loading &&
                                  !cleanupBlocked &&
                                  !_avatarProcessing,
                              onPressed: cleanupBlocked
                                  ? null
                                  : () => _onPressed(context),
                              leading: AnimatedCrossFade(
                                crossFadeState: loading
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: animationDuration,
                                firstChild: const SizedBox(),
                                secondChild: AxiProgressIndicator(
                                  color: context.colorScheme.primaryForeground,
                                  semanticsLabel: l10n.authSignupPending,
                                ),
                              ),
                              trailing: const SizedBox.shrink(),
                              child: Text(l10n.authSignUp),
                            ).withTapBounce(
                              enabled: !loading && !cleanupBlocked,
                            )
                          : const SizedBox.shrink();

                      return Wrap(
                        spacing: 0,
                        runSpacing: 8,
                        children: [
                          backButton,
                          if (showNextButton) continueButton,
                          if (showSubmitButton) submitButton,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AvatarSizeException implements Exception {
  const _AvatarSizeException();
}

class _AvatarSelection {
  const _AvatarSelection({
    required this.template,
    required this.background,
  });

  final AvatarTemplate template;
  final Color background;
}

class _CarouselAvatar {
  const _CarouselAvatar({
    required this.bytes,
    required this.sourceBytes,
    required this.background,
    this.template,
    this.category,
  });

  final Uint8List bytes;
  final Uint8List sourceBytes;
  final AvatarTemplate? template;
  final AvatarTemplateCategory? category;
  final Color background;
}

class _SignupAvatarEditorPanel extends StatefulWidget {
  const _SignupAvatarEditorPanel({
    required this.mode,
    required this.avatarBytesListenable,
    required this.onShuffle,
    required this.onUpload,
    this.sourceBytesProvider,
    this.cropRectProvider,
    this.imageWidthProvider,
    this.imageHeightProvider,
    this.backgroundColorProvider,
    this.onCropChanged,
    this.onCropReset,
    this.onBackgroundChanged,
  });

  final _AvatarEditorMode mode;
  final ValueListenable<Uint8List?> avatarBytesListenable;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onUpload;
  final Uint8List? Function()? sourceBytesProvider;
  final Rect? Function()? cropRectProvider;
  final double? Function()? imageWidthProvider;
  final double? Function()? imageHeightProvider;
  final Color? Function()? backgroundColorProvider;
  final ValueChanged<Rect>? onCropChanged;
  final VoidCallback? onCropReset;
  final ValueChanged<Color>? onBackgroundChanged;

  @override
  State<_SignupAvatarEditorPanel> createState() =>
      _SignupAvatarEditorPanelState();
}

class _SignupAvatarEditorPanelState extends State<_SignupAvatarEditorPanel> {
  bool _shuffling = false;
  int _previewVersion = 0;
  Uint8List? _lastPreviewBytes;
  Rect? _localCropRect;
  double? _lastImageWidth;
  double? _lastImageHeight;
  Rect? _pendingCropRect;
  bool _cropChangeScheduled = false;

  Future<void> _handleShuffle() async {
    if (_shuffling) return;
    setState(() => _shuffling = true);
    try {
      await widget.onShuffle();
    } finally {
      if (mounted) {
        setState(() => _shuffling = false);
      }
    }
  }

  void _scheduleCropChange(Rect rect) {
    _pendingCropRect = rect;
    if (_cropChangeScheduled) return;
    _cropChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cropChangeScheduled = false;
      final next = _pendingCropRect;
      _pendingCropRect = null;
      if (!mounted || next == null) return;
      widget.onCropChanged?.call(next);
      setState(() => _localCropRect = next);
    });
  }

  void _handleCropReset() {
    final rect = widget.cropRectProvider?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCropReset?.call();
      setState(() => _localCropRect = rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final mode = widget.mode;
    final showCrop = mode == _AvatarEditorMode.cropOnly;
    final showColor = mode == _AvatarEditorMode.colorOnly &&
        widget.onBackgroundChanged != null;
    final busy = _shuffling;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final cropBytes = showCrop
            ? widget.sourceBytesProvider?.call() ?? _lastPreviewBytes
            : null;
        final imageWidth = showCrop ? widget.imageWidthProvider?.call() : null;
        final imageHeight =
            showCrop ? widget.imageHeightProvider?.call() : null;
        if (imageWidth != null &&
            imageHeight != null &&
            (_lastImageWidth != imageWidth ||
                _lastImageHeight != imageHeight)) {
          _lastImageWidth = imageWidth;
          _lastImageHeight = imageHeight;
          _localCropRect = null;
        }
        final canEditCrop = showCrop &&
            cropBytes != null &&
            imageWidth != null &&
            imageHeight != null &&
            imageWidth > 0 &&
            imageHeight > 0 &&
            widget.onCropChanged != null &&
            widget.onCropReset != null;

        Widget? cropper;
        if (canEditCrop) {
          final Uint8List safeBytes = cropBytes;
          final double safeImageWidth = imageWidth;
          final double safeImageHeight = imageHeight;
          cropper = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              Text(
                'Crop & focus',
                style:
                    context.textTheme.small.copyWith(color: colors.foreground),
              ),
              Text(
                'Drag or resize the square to frame your avatar. Reset to center the selection.',
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: AvatarCropper(
                    bytes: safeBytes,
                    imageWidth: safeImageWidth,
                    imageHeight: safeImageHeight,
                    cropRect: _localCropRect ??
                        widget.cropRectProvider?.call() ??
                        AvatarCropper.fallbackCropRect(
                          imageWidth: safeImageWidth,
                          imageHeight: safeImageHeight,
                          minCropSide: AvatarEditorCubit.minCropSide,
                        ),
                    onCropChanged: _scheduleCropChange,
                    onCropReset: _handleCropReset,
                    colors: colors,
                    borderRadius: context.radius,
                    minCropSide: AvatarEditorCubit.minCropSide,
                  ),
                ),
              ),
              Text(
                'Only the area inside the circle will appear in the final avatar.',
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ],
          );
        }

        final backgroundColor = widget.backgroundColorProvider?.call();
        final backgroundPicker = showColor &&
                backgroundColor != null &&
                widget.onBackgroundChanged != null
            ? _SignupBackgroundPicker(
                color: backgroundColor,
                onChanged: widget.onBackgroundChanged!,
              )
            : null;

        Widget preview = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12.0,
          children: [
            ValueListenableBuilder<Uint8List?>(
              valueListenable: widget.avatarBytesListenable,
              builder: (_, bytes, __) {
                if (!identical(bytes, _lastPreviewBytes)) {
                  _lastPreviewBytes = bytes;
                  _previewVersion++;
                }
                final previewKey = ValueKey(_previewVersion);
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: AxiAvatar(
                    key: previewKey,
                    jid: 'avatar@axichat',
                    size: 96,
                    subscription: Subscription.none,
                    presence: null,
                    avatarBytes: bytes,
                  ),
                );
              },
            ),
            Text(
              l10n.signupAvatarMenuDescription,
              style: context.textTheme.small
                  .copyWith(color: colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8.0,
              children: [
                ShadButton(
                  onPressed: busy ? null : _handleShuffle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8.0,
                    children: [
                      if (busy)
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primaryForeground,
                            ),
                            backgroundColor:
                                colors.primaryForeground.withValues(alpha: 0.2),
                          ),
                        )
                      else
                        const Icon(LucideIcons.refreshCw, size: 20),
                      Text(l10n.signupAvatarShuffle),
                    ],
                  ),
                ).withTapBounce(),
                ShadButton.outline(
                  onPressed: busy ? null : () => unawaited(widget.onUpload()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8.0,
                    children: [
                      const Icon(LucideIcons.upload),
                      Text(l10n.signupAvatarUploadImage),
                    ],
                  ),
                ).withTapBounce(),
              ],
            ),
          ],
        );

        final previewAndCrop = showCrop && cropper != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12.0,
                children: [
                  preview,
                  cropper,
                ],
              )
            : preview;

        final pickerSlot = AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: showColor && backgroundPicker != null
                ? SizedBox(
                    key: const ValueKey('picker'),
                    width: isWide ? 260 : double.infinity,
                    child: backgroundPicker,
                  )
                : const SizedBox.shrink(key: ValueKey('picker-empty')),
          ),
        );

        Widget editorContent;
        if (isWide) {
          editorContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: previewAndCrop),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: showColor ? 12.0 : 0.0),
                  child: pickerSlot,
                ),
              ),
            ],
          );
        } else {
          editorContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12.0,
            children: [
              previewAndCrop,
              pickerSlot,
            ],
          );
        }

        return ShadCard(
          padding: const EdgeInsets.all(12.0),
          child: editorContent,
        );
      },
    );
  }
}

class _SignupBackgroundPicker extends StatelessWidget {
  const _SignupBackgroundPicker({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final swatches = [
      colors.accent,
      colors.primary,
      colors.secondary,
      colors.destructive,
      colors.muted,
      colors.card,
      colors.background,
      colors.foreground.withValues(alpha: 0.65),
    ];
    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10.0,
        children: [
          Text(
            context.l10n.signupAvatarBackgroundColor,
            style: context.textTheme.small.copyWith(color: colors.foreground),
          ),
          Text(
            'Tint transparent avatars or uploads so the saved circle matches.',
            style:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
          ),
          Material(
            type: MaterialType.transparency,
            child: ColorPicker(
              color: color,
              onColorChanged: onChanged,
              pickersEnabled: const {
                ColorPickerType.both: false,
                ColorPickerType.primary: false,
                ColorPickerType.accent: false,
                ColorPickerType.bw: false,
                ColorPickerType.custom: false,
                ColorPickerType.customSecondary: false,
                ColorPickerType.wheel: true,
              },
              width: 34,
              height: 34,
              spacing: 6,
              runSpacing: 6,
              hasBorder: true,
              borderColor: colors.border,
              borderRadius: context.radius.topLeft.x,
              wheelDiameter: 180,
              wheelWidth: 14,
              showColorCode: true,
              colorCodeHasColor: true,
              colorCodeTextStyle:
                  context.textTheme.small.copyWith(color: colors.foreground),
              colorCodePrefixStyle: context.textTheme.small
                  .copyWith(color: colors.mutedForeground),
              heading: Text(
                'Wheel & hex',
                style:
                    context.textTheme.small.copyWith(color: colors.foreground),
              ),
              subheading: Text(
                'Adjust tint and opacity.',
                style: context.textTheme.small
                    .copyWith(color: colors.mutedForeground),
              ),
              actionButtons: const ColorPickerActionButtons(
                dialogActionButtons: false,
                closeButton: false,
                okButton: false,
              ),
              copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                longPressMenu: false,
                editFieldCopyButton: true,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: swatches.map(
              (swatch) {
                final isSelected = swatch.toARGB32() == color.toARGB32();
                return ColorIndicator(
                  color: swatch,
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  hasBorder: true,
                  borderColor: isSelected ? colors.primary : colors.border,
                  elevation: isSelected ? 2 : 0,
                  isSelected: isSelected,
                  onSelect: () => onChanged(swatch),
                );
              },
            ).toList(),
          ),
          Row(
            children: [
              ColorIndicator(
                color: color,
                width: 44,
                height: 44,
                borderRadius: context.radius.topLeft.x,
                hasBorder: true,
                borderColor: colors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saved background preview',
                  style: context.textTheme.small
                      .copyWith(color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignupAvatarSelector extends StatefulWidget {
  const _SignupAvatarSelector({
    required this.bytes,
    required this.username,
    required this.processing,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String username;
  final bool processing;
  final VoidCallback onTap;

  @override
  State<_SignupAvatarSelector> createState() => _SignupAvatarSelectorState();
}

class _SignupAvatarSelectorState extends State<_SignupAvatarSelector> {
  static const _size = 56.0;
  bool _hovered = false;
  int _previewVersion = 0;

  @override
  void didUpdateWidget(covariant _SignupAvatarSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _previewVersion++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final displayJid = widget.username.isEmpty
        ? 'avatar@axichat'
        : '${widget.username}@preview';
    final overlayVisible = _hovered || widget.processing;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: _size,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: AxiAvatar(
                  key: ValueKey(_previewVersion),
                  jid: displayJid,
                  size: _size,
                  subscription: Subscription.none,
                  presence: null,
                  avatarBytes: widget.bytes,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: overlayVisible ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: colors.background.withAlpha((0.45 * 255).round()),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: widget.processing
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.foreground,
                          ),
                        ),
                      )
                    : Icon(
                        LucideIcons.pencil,
                        color: colors.foreground,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupProgressMeter extends StatelessWidget {
  const _SignupProgressMeter({
    required this.progressValue,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStepLabel,
    required this.animationDuration,
  });

  final double progressValue;
  final int currentStepIndex;
  final int totalSteps;
  final String currentStepLabel;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final targetPercent = (progressValue * 100).clamp(0.0, 100.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetPercent),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedPercent, child) {
        final clampedPercent = animatedPercent.clamp(0.0, 100.0);
        final fillFraction = (clampedPercent / 100).clamp(0.0, 1.0);
        final currentStepNumber =
            (currentStepIndex + 1).clamp(1, totalSteps).toInt();
        return Semantics(
          label: l10n.signupProgressLabel,
          value: l10n.signupProgressValue(
            currentStepNumber,
            totalSteps,
            currentStepLabel,
            clampedPercent.round(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.signupProgressSection,
                    style: context.textTheme.muted,
                  ),
                  Text(
                    '${clampedPercent.round()}%',
                    style: context.textTheme.muted.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fillFraction,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _SignupPasswordStrengthMeter extends StatelessWidget {
  const _SignupPasswordStrengthMeter({
    required this.entropyBits,
    required this.maxEntropyBits,
    required this.strengthLevel,
    required this.showBreachWarning,
    required this.animationDuration,
  });

  final double entropyBits;
  final double maxEntropyBits;
  final _PasswordStrengthLevel strengthLevel;
  final bool showBreachWarning;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final targetBits = entropyBits.clamp(0.0, maxEntropyBits);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetBits),
      duration: animationDuration,
      curve: Curves.easeInOut,
      builder: (context, animatedBits, child) {
        final normalized = (animatedBits / maxEntropyBits).clamp(0.0, 1.0);
        final fillColor = _colorForLevel(strengthLevel, colors);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.signupPasswordStrength,
                  style: context.textTheme.muted,
                ),
                Text(
                  _labelForLevel(strengthLevel, l10n),
                  style: context.textTheme.muted.copyWith(
                    color: fillColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: normalized,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: animationDuration,
              child: showBreachWarning
                  ? Padding(
                      key: const ValueKey('breach-warning'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.signupPasswordBreached,
                        style: context.textTheme.muted.copyWith(
                          color: colors.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  static String _labelForLevel(
    _PasswordStrengthLevel level,
    AppLocalizations l10n,
  ) {
    switch (level) {
      case _PasswordStrengthLevel.empty:
        return l10n.signupStrengthNone;
      case _PasswordStrengthLevel.weak:
        return l10n.signupStrengthWeak;
      case _PasswordStrengthLevel.medium:
        return l10n.signupStrengthMedium;
      case _PasswordStrengthLevel.stronger:
        return l10n.signupStrengthStronger;
    }
  }

  static Color _colorForLevel(
    _PasswordStrengthLevel level,
    ShadColorScheme colors,
  ) {
    switch (level) {
      case _PasswordStrengthLevel.weak:
      case _PasswordStrengthLevel.empty:
        return colors.destructive;
      case _PasswordStrengthLevel.medium:
        return _strengthMediumColor;
      case _PasswordStrengthLevel.stronger:
        return _strengthStrongColor;
    }
  }
}

class _SignupInsecurePasswordNotice extends StatelessWidget {
  const _SignupInsecurePasswordNotice({
    required this.reason,
    required this.allowInsecurePassword,
    required this.loading,
    required this.pwnedCheckInProgress,
    required this.showAllowInsecureError,
    required this.animationDuration,
    required this.resetTick,
    required this.onChanged,
  });

  final _InsecurePasswordReason? reason;
  final bool allowInsecurePassword;
  final bool loading;
  final bool pwnedCheckInProgress;
  final bool showAllowInsecureError;
  final Duration animationDuration;
  final int resetTick;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: reason == null
          ? const SizedBox.shrink()
          : Column(
              key: ValueKey(reason),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AxiCheckboxFormField(
                  key: ValueKey('${reason!.name}-$resetTick'),
                  enabled: !loading && !pwnedCheckInProgress,
                  initialValue: allowInsecurePassword,
                  inputLabel: Text(l10n.signupRiskAcknowledgement),
                  inputSublabel: Text(_reasonDescription(reason!, l10n)),
                  onChanged: onChanged,
                ),
                AnimatedOpacity(
                  opacity:
                      showAllowInsecureError && !allowInsecurePassword ? 1 : 0,
                  duration: animationDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      l10n.signupRiskError,
                      style: TextStyle(
                        color: context.colorScheme.destructive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static String _reasonDescription(
    _InsecurePasswordReason reason,
    AppLocalizations l10n,
  ) {
    if (reason == _InsecurePasswordReason.breached) {
      return l10n.signupRiskAllowBreach;
    }
    return l10n.signupRiskAllowWeak;
  }
}

class _CaptchaFrame extends StatelessWidget {
  const _CaptchaFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(14);
    return Container(
      width: _SignupFormState.captchaSize.width,
      height: _SignupFormState.captchaSize.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.border),
        color: colors.card,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _CaptchaImage extends StatefulWidget {
  const _CaptchaImage({
    required this.url,
    required this.onLoaded,
    required this.onInitialError,
    required this.showErrorMessageOnError,
  });

  final String url;
  final VoidCallback onLoaded;
  final VoidCallback onInitialError;
  final bool showErrorMessageOnError;

  @override
  State<_CaptchaImage> createState() => _CaptchaImageState();
}

class _CaptchaImageState extends State<_CaptchaImage> {
  bool _isReady = false;
  bool _readyNotified = false;

  @override
  void didUpdateWidget(covariant _CaptchaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _isReady = false;
      _readyNotified = false;
    }
  }

  void _handleImageReady() {
    if (_readyNotified) return;
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
      widget.onLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      widget.url,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, _) {
        if (frame != null) {
          _handleImageReady();
        }
        return child;
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        if (widget.showErrorMessageOnError) {
          return const _CaptchaErrorMessage();
        }
        widget.onInitialError();
        return const _CaptchaSkeleton();
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: _isReady ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: const _CaptchaSkeleton(),
        ),
        AnimatedOpacity(
          opacity: _isReady ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: image,
        ),
      ],
    );
  }
}

class _CaptchaSkeleton extends StatefulWidget {
  const _CaptchaSkeleton();

  @override
  State<_CaptchaSkeleton> createState() => _CaptchaSkeletonState();
}

class _CaptchaSkeletonState extends State<_CaptchaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colorScheme.border.withValues(alpha: 0.35);
    final highlight = context.colorScheme.card.withValues(alpha: 0.8);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shimmer = _controller.value;
          final start = (shimmer - 0.25).clamp(0.0, 1.0);
          final mid = shimmer.clamp(0.0, 1.0);
          final end = (shimmer + 0.25).clamp(0.0, 1.0);
          return SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, highlight, base],
                  stops: [start, mid, end],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CaptchaErrorMessage extends StatelessWidget {
  const _CaptchaErrorMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox.expand(
      child: Center(
        child: Text(
          l10n.signupCaptchaErrorMessage,
          textAlign: TextAlign.center,
          style: context.textTheme.muted.copyWith(
            color: context.colorScheme.destructive,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
