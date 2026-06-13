// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/email_html_logging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('masks text content while preserving structure and styles', () {
    const html =
        '<table width="600" class="wrapper" style="background:#fff">'
        '<tr><td style="padding:12px">Hello Eliot, your code is 4821</td>'
        '</tr></table>';

    final masked = maskEmailHtml(html);

    expect(masked, contains('width="600"'));
    expect(masked, contains('class="wrapper"'));
    expect(masked, contains('background:#fff'));
    expect(masked, contains('padding:12px'));
    expect(masked, contains('xxxxx xxxxx, xxxx xxxx xx 0000'));
    expect(masked, isNot(contains('Eliot')));
    expect(masked, isNot(contains('4821')));
  });

  test('masks link targets but keeps the host', () {
    const html =
        '<a href="https://tracker.example.com/click?token=secret123">'
        'Unsubscribe</a>';

    final masked = maskEmailHtml(html);

    expect(masked, contains('https://tracker.example.com/masked'));
    expect(masked, isNot(contains('secret123')));
    expect(masked, isNot(contains('Unsubscribe')));
  });

  test('collapses data and cid image sources', () {
    const html =
        '<img src="data:image/png;base64,AAAABBBB">'
        '<img src="cid:logo@example">';

    final masked = maskEmailHtml(html);

    expect(masked, contains('data:image/png;base64,masked-length-'));
    expect(masked, isNot(contains('AAAABBBB')));
    expect(masked, contains('cid:masked'));
    expect(masked, isNot(contains('logo@example')));
  });

  test('keeps css rules and masks urls inside them', () {
    const html =
        '<style>.hero{width:600px;background:url('
        "'https://cdn.example.com/secret/banner.png')}</style>"
        '<div class="hero">Promo text</div>';

    final masked = maskEmailHtml(html);

    expect(masked, contains('width:600px'));
    expect(masked, contains('https://cdn.example.com/masked'));
    expect(masked, isNot(contains('banner.png')));
    expect(masked, isNot(contains('Promo text')));
  });

  test('preserves outlook conditional markers and masks comment bodies', () {
    const html =
        '<!--[if mso]><table><tr><td>outlook secret</td>'
        '<td><img src="https://cdn.example.com/private/image.png"></td>'
        '</tr></table><![endif]-->'
        '<!-- internal campaign note -->'
        '<p>Body</p>';

    final masked = maskEmailHtml(html);

    expect(masked, contains('[if mso]'));
    expect(masked, contains('<![endif]'));
    expect(masked, contains('https://cdn.example.com/masked'));
    expect(masked, isNot(contains('outlook')));
    expect(masked, isNot(contains('secret')));
    expect(masked, isNot(contains('private/image.png')));
    expect(masked, isNot(contains('campaign')));
  });
}
