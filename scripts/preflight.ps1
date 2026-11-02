# 启动前检查 Codex workspace-write 沙箱能否给可写根加权限。
# Codex 每次启动都要在工作目录（及 --add-dir）上写一条沙箱 SID 的显式 ACE，需要 WRITE_DAC。
# 非提权进程拿不到 WRITE_DAC、目录上也还没有沙箱 ACE 时必然失败
# （日志表现为 setup refresh had errors / write ACE failed ... 拒绝访问）。
# 典型情形：属主是 BUILTIN\Administrators（提权进程建的目录），本用户只有继承来的修改权。
# 路径经环境变量 CB_PATHS 传入（| 分隔），避开命令行中文编码问题。
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

Add-Type -Namespace CodexBridge -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(
    string name, uint access, uint share, IntPtr sa, uint disposition, uint flags, IntPtr template);
'@

function Test-WriteDac([string]$path) {
    # READ_CONTROL | WRITE_DAC，FILE_FLAG_BACKUP_SEMANTICS 以打开目录；只打开不改动
    $h = [CodexBridge.Native]::CreateFileW($path, 0x00060000, 7, [IntPtr]::Zero, 3, 0x02000000, [IntPtr]::Zero)
    $ok = -not $h.IsInvalid
    $h.Dispose()
    return $ok
}

$capSids = @()
$capFile = Join-Path $env:USERPROFILE '.codex\cap_sid'
if (Test-Path -LiteralPath $capFile) {
    $cap = Get-Content -LiteralPath $capFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $capSids = @($cap.workspace, $cap.readonly)
    foreach ($k in 'workspace_by_cwd', 'writable_root_by_path') {
        if ($cap.$k) { $capSids += @($cap.$k.PSObject.Properties | ForEach-Object { $_.Value }) }
    }
}

$bad = @()
foreach ($p in ($env:CB_PATHS -split '\|' | Where-Object { $_ })) {
    if (Test-WriteDac $p) { continue }
    $acl = Get-Acl -LiteralPath $p
    $explicit = $acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]) | ForEach-Object { $_.IdentityReference.Value }
    if ($explicit | Where-Object { $capSids -contains $_ }) { continue }
    $bad += $p
    Write-Output ("无法改权限（属主 {0}，且尚无沙箱权限）: {1}" -f $acl.Owner, $p)
}
if ($bad.Count -gt 0) {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Output ""
    Write-Output "Codex 沙箱会初始化失败。根治：在管理员 PowerShell 里给数据根目录授本人可继承的改权限资格（只授本人，不授组），一次即可："
    Write-Output ("  icacls `"<数据根目录>`" /grant `"{0}:(OI)(CI)(RC,WDAC)`"" -f $user)
    Write-Output "把 <数据根目录> 换成覆盖工作目录的上级目录。授完后原任务书原样重跑。"
    exit 3
}
exit 0
