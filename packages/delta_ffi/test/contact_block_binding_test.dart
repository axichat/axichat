import 'dart:ffi';

import 'package:delta_ffi/src/bindings.dart';
import 'package:test/test.dart';

int? _contactId;
int? _blockFlag;

void _dcBlockContact(
  Pointer<dc_context_t> context,
  int contactId,
  int block,
) {
  _contactId = contactId;
  _blockFlag = block;
}

void main() {
  setUp(() {
    _contactId = null;
    _blockFlag = null;
  });

  test('dc_block_contact binds the block flag argument', () {
    final binding = DeltaChatBindings.fromLookup(
      <T extends NativeType>(symbolName) {
        expect(symbolName, 'dc_block_contact');
        return Pointer.fromFunction<
                Void Function(
                    Pointer<dc_context_t>, Uint32, Int)>(_dcBlockContact)
            .cast<T>();
      },
    );

    binding.dc_block_contact(Pointer<dc_context_t>.fromAddress(1), 42, 0);

    expect(_contactId, 42);
    expect(_blockFlag, 0);
  });
}
