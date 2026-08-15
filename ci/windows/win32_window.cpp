#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

/// Window attribute that controls the color of the window border.
/// Win11 22H2+. Redefined for older SDKs.
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

/// Window attribute that controls the color of the window caption.
/// Win11 22H2+. Redefined for older SDKs.
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

/// Height (in logical pixels) of the draggable strip at the top of the window.
/// Must match the height of the Flutter drag strip.
constexpr int kDragBandHeight = 36;

/// Width (in logical pixels) reserved at the top-right of the drag strip for
/// the custom minimize / fullscreen / close buttons.
constexpr int kWindowControlRightWidth = 120;

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

// Returns the DPI of the given window using GDI so this compiles against any
// Windows SDK version. The process is per-monitor DPI aware, so this reflects
// the DPI of the monitor the window is on.
UINT GetWindowDpi(HWND hwnd) {
  HDC dc = GetDC(hwnd);
  UINT dpi = dc ? static_cast<UINT>(GetDeviceCaps(dc, LOGPIXELSX)) : 96;
  if (dc) {
    ReleaseDC(hwnd, dc);
  }
  return dpi > 0 ? dpi : 96;
}

// Original window procedure of the hosted Flutter view, saved before the view
// is subclassed so hit testing can be customized.
WNDPROC g_original_flutter_view_proc = nullptr;

// Subclass procedure installed on the Flutter view window.
//
// Real input hit-testing is performed against this child window, so the
// draggable top band is implemented here by returning HTCAPTION. This lets the
// borderless window be moved by dragging the top strip while keeping the
// custom window-control buttons (top-right) clickable.
LRESULT CALLBACK FlutterViewSubclassProc(HWND hwnd,
                                         UINT const message,
                                         WPARAM const wparam,
                                         LPARAM const lparam) noexcept {
  if (message == WM_NCHITTEST) {
    LRESULT result =
        CallWindowProc(g_original_flutter_view_proc, hwnd, message, wparam, lparam);
    if (result == HTCLIENT) {
      POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &pt);

      RECT client;
      GetClientRect(hwnd, &client);
      const int width = client.right - client.left;

      UINT dpi = GetWindowDpi(hwnd);
      const int band_height = MulDiv(kDragBandHeight, dpi, 96);
      const int reserved_width = MulDiv(kWindowControlRightWidth, dpi, 96);

      if (pt.y >= 0 && pt.y < band_height && pt.x < width - reserved_width) {
        return HTCAPTION;
      }
    }
    return result;
  }
  return CallWindowProc(g_original_flutter_view_proc, hwnd, message, wparam, lparam);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // Borderless (no title bar / window buttons) but still resizable.
  // WS_MAXIMIZEBOX is intentionally omitted so a double-click on the drag
  // band does not put the frameless window into a stuck maximized state.
  const DWORD window_style =
      WS_POPUP | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX;
  HWND window = CreateWindow(
      window_class, title.c_str(), window_style,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  // Blend the window border with the dark app UI (Color 0xFF101A2E).
  COLORREF border_color = RGB(0x10, 0x1A, 0x2E);
  DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,
                        sizeof(border_color));
  DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &border_color,
                        sizeof(border_color));

  ApplyRoundedCorners();

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Run() {
  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_GETMINMAXINFO: {
      auto mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      UINT dpi = GetWindowDpi(hwnd);
      mmi->ptMinTrackSize.x = MulDiv(360, dpi, 96);
      mmi->ptMinTrackSize.y = MulDiv(360, dpi, 96);
      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      ApplyRoundedCorners();
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Minimize() {
  if (window_handle_) {
    ShowWindow(window_handle_, SW_MINIMIZE);
  }
}

void Win32Window::Close() {
  if (window_handle_) {
    PostMessage(window_handle_, WM_CLOSE, 0, 0);
  }
}

void Win32Window::ToggleFullScreen() {
  if (!window_handle_) {
    return;
  }

  if (!fullscreen_) {
    // Remember the current placement so we can restore it later.
    GetWindowPlacement(window_handle_, &saved_placement_);

    HMONITOR monitor = MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO monitor_info{};
    monitor_info.cbSize = sizeof(MONITORINFO);
    if (!GetMonitorInfo(monitor, &monitor_info)) {
      return;
    }

    const RECT rect = monitor_info.rcMonitor;
    const LONG style = static_cast<LONG>(GetWindowLongPtr(window_handle_, GWL_STYLE));
    SetWindowLongPtr(window_handle_, GWL_STYLE, style & ~WS_THICKFRAME);
    SetWindowPos(window_handle_, HWND_TOP, rect.left, rect.top,
                 rect.right - rect.left, rect.bottom - rect.top,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOACTIVATE);
    fullscreen_ = true;
    ApplyRoundedCorners();
  } else {
    const LONG style = static_cast<LONG>(GetWindowLongPtr(window_handle_, GWL_STYLE));
    SetWindowLongPtr(window_handle_, GWL_STYLE, style | WS_THICKFRAME);
    SetWindowPlacement(window_handle_, &saved_placement_);
    fullscreen_ = false;
    ApplyRoundedCorners();
  }
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  // Subclass the Flutter view so the top strip can be used to drag the
  // borderless window around.
  g_original_flutter_view_proc =
      reinterpret_cast<WNDPROC>(SetWindowLongPtr(
          content, GWLP_WNDPROC,
          reinterpret_cast<LONG_PTR>(&FlutterViewSubclassProc)));

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

void Win32Window::ApplyRoundedCorners() {
  if (!window_handle_) {
    return;
  }
  RECT rect;
  if (!GetWindowRect(window_handle_, &rect)) {
    return;
  }
  const int width = rect.right - rect.left;
  const int height = rect.bottom - rect.top;

  HRGN region = nullptr;
  if (fullscreen_) {
    region = CreateRectRgn(0, 0, width + 1, height + 1);
  } else {
    region = CreateRoundRectRgn(0, 0, width + 1, height + 1, 13, 13);
  }
  SetWindowRgn(window_handle_, region, TRUE);
}
