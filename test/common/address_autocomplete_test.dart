import 'package:axichat/src/common/address_autocomplete.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggests known domains after local part and at sign', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        knownDomains: const <String>{'axi.im', 'gmail.com'},
        requireEmailAddress: false,
      ),
      const <String>['alice@axi.im', 'alice@gmail.com'],
    );
  });

  test('shows popular domains first when domain is empty', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        knownDomains: const <String>{
          'custom.example',
          'aol.com',
          'protonmail.com',
          'hotmail.com',
          'gmail.com',
          'yahoo.com',
          'tuta.com',
          'outlook.com',
          'axi.im',
        },
      ),
      const <String>[
        'alice@axi.im',
        'alice@gmail.com',
        'alice@outlook.com',
        'alice@hotmail.com',
        'alice@tuta.com',
        'alice@protonmail.com',
        'alice@aol.com',
        'alice@yahoo.com',
      ],
    );
  });

  test('shows primary domain before axi domain', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        primaryDomain: 'example.net',
        knownDomains: const <String>{'axi.im', 'example.net', 'gmail.com'},
      ),
      const <String>['alice@example.net', 'alice@axi.im', 'alice@gmail.com'],
    );
  });

  test('does not duplicate axi when it is the primary domain', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        primaryDomain: 'axi.im',
        knownDomains: const <String>{'axi.im', 'gmail.com'},
      ),
      const <String>['alice@axi.im', 'alice@gmail.com'],
    );
  });

  test('shows known contact domains before popular domains', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        primaryDomain: 'axi.im',
        knownDomains: const <String>{'axi.im', 'conversations.im', 'gmail.com'},
        knownAddresses: const <String>['bob@conversations.im'],
      ),
      const <String>[
        'alice@axi.im',
        'alice@conversations.im',
        'alice@gmail.com',
      ],
    );
  });

  test('ranks popular known domains by distinct contact count', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        primaryDomain: 'axi.im',
        knownDomains: const <String>{
          'axi.im',
          'gmail.com',
          'outlook.com',
          'hotmail.com',
        },
        knownAddresses: const <String>[
          'bob@gmail.com',
          'carol@gmail.com',
          'dave@outlook.com',
        ],
      ),
      const <String>[
        'alice@axi.im',
        'alice@gmail.com',
        'alice@outlook.com',
        'alice@hotmail.com',
      ],
    );
  });

  test('includes non-popular domains after the user types a match', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@cu',
        knownDomains: const <String>{
          'custom.example',
          'customer.example',
          'gmail.com',
        },
      ),
      const <String>['alice@custom.example', 'alice@customer.example'],
    );
  });

  test('orders exact known addresses before domain completions', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@g',
        knownDomains: const <String>{'gmail.com', 'gmx.com'},
        knownAddresses: const <String>['alice@gmail.com'],
      ).first,
      'alice@gmail.com',
    );
  });

  test('excludes already selected addresses', () {
    expect(
      addressAutocompleteSuggestions(
        input: 'alice@',
        knownDomains: const <String>{'axi.im'},
        excludedAddresses: const <String>{'alice@axi.im'},
        requireEmailAddress: false,
      ),
      isEmpty,
    );
  });
}
