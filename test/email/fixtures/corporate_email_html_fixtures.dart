/// Realistic corporate-email HTML fixtures for rendering regression tests.
///
/// Test-only fixtures; they are intentionally not registered as app assets.
library;

/// CSS-heavy multipart-style newsletter body: `<style>` blocks, media
/// queries, table layout, and non-empty visible body copy.
const String corporateCssHeavyEmailHtml = r'''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Acme quarterly newsletter</title>
<style type="text/css">
  body, table, td { font-family: Helvetica, Arial, sans-serif !important; }
  .preheader { display: none; max-height: 0; overflow: hidden; }
  .button { background: #1a82e2; border-radius: 6px; color: #ffffff; padding: 12px 24px; text-decoration: none; }
  @media only screen and (max-width: 600px) {
    .container { width: 100% !important; }
    .stack { display: block !important; width: 100% !important; }
  }
  @media (prefers-color-scheme: dark) {
    body { background-color: #1f1f1f !important; color: #eaeaea !important; }
  }
</style>
</head>
<body style="margin: 0; padding: 0; background-color: #f4f4f7;">
  <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0">
    <tr><td style="padding: 24px;">
      <h1 style="font-size: 20px; margin: 0;">Acme Q3 results</h1>
      <p style="margin: 16px 0;">Hi team, revenue grew 12% quarter over quarter and churn fell below 2%.</p>
      <p style="margin: 16px 0;">The full report is available on the intranet dashboard.</p>
      <a href="https://intranet.acme.example/reports/q3" class="button">Open the report</a>
    </td></tr>
  </table>
</body>
</html>
''';

/// Visible body copy expected from [corporateCssHeavyEmailHtml].
const String corporateCssHeavyEmailVisibleText =
    'revenue grew 12% quarter over quarter';

/// Stylesheet text a naive MIME flattening leaks into the plain-text part of
/// [corporateCssHeavyEmailHtml].
const String corporateCssHeavyEmailLeakedBodyText = r'''
body, table, td { font-family: Helvetica, Arial, sans-serif !important; }
.preheader { display: none; max-height: 0; overflow: hidden; }
@media only screen and (max-width: 600px) {
  .container { width: 100% !important; }
}
''';

/// text/html-only billing notice whose visible text is non-empty and whose
/// only text representation is the HTML part.
const String corporateTextHtmlOnlyEmailHtml = r'''
<html>
<body>
<p>Hello Dana,</p>
<p>Your subscription renews on 30 June 2026. No action is needed.</p>
<p>Best regards,<br />The billing team</p>
</body>
</html>
''';

/// Visible body copy expected from [corporateTextHtmlOnlyEmailHtml].
const String corporateTextHtmlOnlyEmailVisibleText =
    'Your subscription renews on 30 June 2026';

/// Style/metadata-only body with no visible text: the CSS-leak case where the
/// HTML part carries only stylesheets, metadata, and empty containers.
const String corporateStyleOnlyEmailHtml = r'''
<html>
<head>
<meta charset="utf-8" />
<style type="text/css">
  .footer { color: #999999; font-size: 12px; }
  @media only screen and (max-width: 480px) {
    .footer { font-size: 10px; }
  }
</style>
</head>
<body style="margin: 0;">
  <div style="display: none;"></div>
  <!-- tracking pixel removed -->
</body>
</html>
''';

/// Stylesheet text a naive MIME flattening leaks into the plain-text part of
/// [corporateStyleOnlyEmailHtml].
const String corporateStyleOnlyEmailLeakedBodyText = r'''
.footer { color: #999999; font-size: 12px; }
@media only screen and (max-width: 480px) {
  .footer { font-size: 10px; }
}
''';
