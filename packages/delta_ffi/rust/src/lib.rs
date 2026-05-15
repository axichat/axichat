pub use deltachat::*;

use std::collections::HashMap;
use std::ffi::CString;
use std::io::Write;
use std::ptr;
use std::sync::{Arc, LazyLock, Mutex};
use std::time::Duration;

use brotli::DecompressorWriter;
use deltachat_core::context::Context;
use deltachat_core::message::MsgId;
use deltachat_core::sql;
use tokio::runtime::Runtime;
use tokio::sync::Notify;

const MIME_HEADERS_QUERY: &str = "SELECT mime_headers, mime_compressed FROM msgs WHERE id=?";
const MIME_HEADERS_COLUMN_HEADERS: usize = 0;
const MIME_HEADERS_COLUMN_COMPRESSED: usize = 1;
const BROTLI_BUFFER_SIZE: usize = 4096;
const NULL_BYTE: u8 = 0;

static _RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("failed to create tokio runtime"));
static _ACTIVE_BACKGROUND_FETCHES: LazyLock<Mutex<HashMap<usize, Arc<Notify>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn _block_on<T>(future: impl std::future::Future<Output = T>) -> T {
    _RUNTIME.block_on(future)
}

fn _register_active_background_fetch(accounts: usize) -> Option<Arc<Notify>> {
    let mut active = _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned");
    if active.contains_key(&accounts) {
        return None;
    }
    let signal = Arc::new(Notify::new());
    active.insert(accounts, signal.clone());
    Some(signal)
}

fn _stop_active_background_fetch(accounts: usize) -> bool {
    let active = _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned");
    let Some(signal) = active.get(&accounts) else {
        return false;
    };
    signal.notify_one();
    true
}

fn _finish_active_background_fetch(accounts: usize) {
    _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned")
        .remove(&accounts);
}

struct _ActiveBackgroundFetchGuard {
    accounts: usize,
}

impl Drop for _ActiveBackgroundFetchGuard {
    fn drop(&mut self) {
        _finish_active_background_fetch(self.accounts);
    }
}

fn _read_mime_headers(context: &Context, msg_id: MsgId) -> Option<Vec<u8>> {
    let query = context.sql();
    let fetched = _block_on(query.query_row(MIME_HEADERS_QUERY, (msg_id,), |row| {
        let headers = sql::row_get_vec(row, MIME_HEADERS_COLUMN_HEADERS)?;
        let compressed: Option<bool> = row.get(MIME_HEADERS_COLUMN_COMPRESSED)?;
        Ok((headers, compressed.unwrap_or(false)))
    }))
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
    let mut decompressor = DecompressorWriter::new(Vec::new(), BROTLI_BUFFER_SIZE);
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
        .filter(|byte| *byte != NULL_BYTE)
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

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_accounts_background_fetch(
    accounts: *mut dc_accounts_t,
    timeout_seconds: u64,
) -> i32 {
    if accounts.is_null() || timeout_seconds <= 2 {
        eprintln!("ignoring careless call to axichat_dc_accounts_background_fetch()");
        return 0;
    }

    let accounts_key = accounts as usize;
    let Some(stop_signal) = _register_active_background_fetch(accounts_key) else {
        return 0;
    };
    let _active_fetch = _ActiveBackgroundFetchGuard {
        accounts: accounts_key,
    };

    {
        let accounts = &*accounts;
        let background_fetch = {
            let accounts = _block_on(accounts.read());
            accounts.background_fetch(Duration::from_secs(timeout_seconds))
        };
        _block_on(async {
            tokio::select! {
                _ = background_fetch => 1,
                _ = stop_signal.notified() => 0,
            }
        })
    }
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_accounts_stop_background_fetch(
    accounts: *mut dc_accounts_t,
) -> i32 {
    if accounts.is_null() {
        eprintln!("ignoring careless call to axichat_dc_accounts_stop_background_fetch()");
        return 0;
    }
    if _stop_active_background_fetch(accounts as usize) {
        return 1;
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unique_accounts_key() -> usize {
        static NEXT_KEY: LazyLock<Mutex<usize>> = LazyLock::new(|| Mutex::new(1000));
        let mut key = NEXT_KEY.lock().expect("test key registry poisoned");
        *key += 1;
        *key
    }

    #[test]
    fn duplicate_active_fetch_is_rejected() {
        let key = unique_accounts_key();
        let first = _register_active_background_fetch(key);
        assert!(first.is_some());
        let second = _register_active_background_fetch(key);
        assert!(second.is_none());
        _finish_active_background_fetch(key);
    }

    #[test]
    fn stop_signals_active_fetch_only() {
        let key = unique_accounts_key();
        let other_key = unique_accounts_key();
        let signal = _register_active_background_fetch(key).unwrap();

        assert!(_stop_active_background_fetch(key));
        assert!(!_stop_active_background_fetch(other_key));
        assert!(_block_on(async {
            tokio::time::timeout(Duration::from_millis(100), signal.notified())
                .await
                .is_ok()
        }));

        _finish_active_background_fetch(key);
    }

    #[test]
    fn stop_without_active_fetch_does_not_create_pending_stop() {
        let key = unique_accounts_key();

        assert!(!_stop_active_background_fetch(key));
        let signal = _register_active_background_fetch(key).unwrap();
        assert!(!_block_on(async {
            tokio::time::timeout(Duration::from_millis(10), signal.notified())
                .await
                .is_ok()
        }));

        _finish_active_background_fetch(key);
    }

    #[test]
    fn cleanup_removes_active_entry() {
        let key = unique_accounts_key();

        assert!(_register_active_background_fetch(key).is_some());
        _finish_active_background_fetch(key);
        assert!(_register_active_background_fetch(key).is_some());

        _finish_active_background_fetch(key);
    }
}
