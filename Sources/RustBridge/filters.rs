use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn rust_filter_url(raw_input: *const c_char) -> *mut c_char {
    let c_str = unsafe {
        assert!(!raw_input.is_null());
        CStr::from_ptr(raw_input)
    };

    let text = c_str.to_string_lossy();
    let cleaned = text
        .trim()
        .trim_start_matches("http://")
        .trim_start_matches("https://")
        .trim_start_matches("www.")
        .to_string();

    let safe = if cleaned.is_empty() {
        "https://example.com".to_string()
    } else {
        format!("https://{}", cleaned)
    };

    CString::new(safe)
        .unwrap()
        .into_raw()
}

#[no_mangle]
pub extern "C" fn rust_release_string(ptr: *mut c_char) {
    unsafe {
        if !ptr.is_null() {
            let _ = CString::from_raw(ptr);
        }
    }
}

#[no_mangle]
pub extern "C" fn rust_should_block_url(raw_input: *const c_char) -> u8 {
    let c_str = unsafe {
        if raw_input.is_null() {
            return 0;
        }
        CStr::from_ptr(raw_input)
    };

    let input = c_str.to_string_lossy();
    let blocked = ["javascript:", "data:", "file:"]
        .iter()
        .any(|prefix| input.trim_start().to_ascii_lowercase().starts_with(prefix));

    if blocked { 1 } else { 0 }
}
