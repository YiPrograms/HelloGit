#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

; VirtualDesktopAccessor.dll must be beside this script.
VDA_PATH := A_ScriptDir "\VirtualDesktopAccessor.dll"
hVDA := DllCall("LoadLibrary", "Str", VDA_PATH, "Ptr")

if !hVDA {
    MsgBox("Could not load VirtualDesktopAccessor.dll")
    ExitApp()
}

GetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "GetDesktopCount", "Ptr")
GetCurrentDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "GetCurrentDesktopNumber", "Ptr")
MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "MoveWindowToDesktopNumber", "Ptr")
RegisterPostMessageHookProc := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "RegisterPostMessageHook", "Ptr")

GetDesktopCount() {
    global GetDesktopCountProc
    return DllCall(GetDesktopCountProc, "Int")
}

SwitchDesktop(direction) {
    Send(direction < 0 ? "#^{Left}" : "#^{Right}")
}

MoveWindowAndFollow(direction) {
    global GetCurrentDesktopNumberProc, MoveWindowToDesktopNumberProc

    current := DllCall(GetCurrentDesktopNumberProc, "Int")
    target := current + direction
    count := GetDesktopCount()

    if target < 0 || target >= count
        return

    hwnd := WinGetID("A")
    result := DllCall(MoveWindowToDesktopNumberProc, "Ptr", hwnd, "Int", target, "Int")

    if result = -1
        return

    ; Switch with Windows' native shortcut so its normal animation is retained.
    SwitchDesktop(direction)
}

ShowDesktopIndicator(desktop, count) {
    dots := ""

    Loop count {
        dots .= (A_Index = desktop ? "●" : "○")
        if A_Index < count
            dots .= "  "
    }

    CoordMode("ToolTip", "Screen")
    ToolTip("Desktop " desktop " / " count "`n" dots, A_ScreenWidth // 2 - 90, 70)
    SetTimer(HideDesktopIndicator, -700)
}

HideDesktopIndicator() {
    ToolTip()
}

; VirtualDesktopAccessor desktop-change notification.
DESKTOP_CHANGED := 0x1400 + 30
DllCall(RegisterPostMessageHookProc, "Ptr", A_ScriptHwnd, "Int", DESKTOP_CHANGED, "Int")
OnMessage(DESKTOP_CHANGED, DesktopChanged)

DesktopChanged(oldDesktop, newDesktop, *) {
    ShowDesktopIndicator(newDesktop + 1, GetDesktopCount())
}

; KDE-like shortcuts
#Left::SwitchDesktop(-1)
#Right::SwitchDesktop(1)

; Move active window to adjacent desktop and follow it.
#!Left::MoveWindowAndFollow(-1)
#!Right::MoveWindowAndFollow(1)

; Launch Windows Terminal.
#t::Run("wt.exe")

; Gracefully close the active window.
#q::WinClose("A")
