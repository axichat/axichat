pub use deltachat::*;

use std::ffi::CString;
use std::io::Write;
use std::ptr;
use std::sync::LazyLock;

use brotli::DecompressorWriter;
use deltachat_core::context::Context;
use deltachat_core::message::MsgId;
use deltachat_core::sql;
use tokio::runtime::Runtime;

const _mime_headers_query: &str =
    "SELECT mime_headers, mime_compressed FROM msgs WHERE id=?";
const _mime_headers_column_headers: usize = 0;
const _mime_headers_column_compressed: usize = 1;
const _brotli_buffer_size: usize = 4096;
const _null_byte: u8 = 0;

static _runtime: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("failed to create tokio runtime"));

fn _block_on<T>(future: impl std::future::Future<Output = T>) -> T {
    _runtime.block_on(future)
}

fn _read_mime_headers(context: &Context, msg_id: MsgId) -> Option<Vec<u8>> {
    let query = context.sql();
    let fetched = _block_on(query.query_row(
        _mime_headers_query,
        (msg_id,),
        |row| {
            let headers = sql::row_get_vec(row, _mime_headers_column_headers)?;
            let compressed: Option<bool> = row.get(_mime_headers_column_compressed)?;
            Ok((headers, compressed.unwrap_or(false)))
        },
    ))
    .ok()?;
    let (headers, compressed) = fetched;
    if headers.is_empty() {
        return None;
    }
    if !compressed {
        return Some(headers);
    }
    _decompress_headers(&headers)
}

fn _decompress_headers(compressed: &[u8]) -> Option<Vec<u8>> {
    if compressed.is_empty() {
        return None;
    }
    let mut decompressor = DecompressorWriter::new(Vec::new(), _brotli_buffer_size);
    if decompressor.write_all(compressed).is_err() {
        return None;
    }
    if decompressor.flush().is_err() {
        return None;
    }
    let bytes = std::mem::take(decompressor.get_mut());
    if bytes.is_empty() {
        return None;
    }
    Some(bytes)
}

fn _headers_to_c_string(headers: &[u8]) -> *mut std::os::raw::c_char {
    let sanitized: Vec<u8> = headers
        .iter()
        .copied()
        .filter(|byte| *byte != _null_byte)
        .collect();
    let decoded = String::from_utf8_lossy(&sanitized).to_string();
    CString::new(decoded)
        .unwrap_or_else(|_| CString::new(Vec::new()).unwrap())
        .into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn dc_get_msg_mime_headers(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut std::os::raw::c_char {
    if context.is_null() {
        return ptr::null_mut();
    }
    let ctx = &*context;
    let headers = match _read_mime_headers(ctx, MsgId::new(msg_id)) {
        Some(headers) => headers,
        None => return ptr::null_mut(),
    };
    _headers_to_c_string(&headers)
}
