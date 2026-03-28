## Fix crash when closing a connection before initialization completes

Closing a connection before its internal initialization completed could cause a crash. This was a rare race condition most likely to occur on macOS arm64.
