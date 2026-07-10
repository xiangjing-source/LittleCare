$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = Join-Path $WorkspaceRoot '.tooling\jdk'
$env:ANDROID_HOME = Join-Path $WorkspaceRoot '.tooling\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = Join-Path $WorkspaceRoot '.tooling\pub-cache'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME = Join-Path $WorkspaceRoot '.tooling\gradle-home'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:PATH = @(
  (Join-Path $WorkspaceRoot '.tooling\flutter\bin')
  (Join-Path $env:ANDROID_HOME 'platform-tools')
  (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin')
  (Join-Path $env:JAVA_HOME 'bin')
  $env:PATH
) -join ';'

Write-Host 'Workshop Flutter/Android environment is ready.'

function Build-WorkshopAndroid {
  param(
    [ValidateSet('Debug', 'Release')]
    [string]$Mode = 'Debug',
    [switch]$AppBundle
  )

  Push-Location $WorkspaceRoot
  try {
    if ($Mode -eq 'Release') {
      throw '正式发布签名尚未启用；请先按 Flutter Android 发布文档配置上传密钥。'
    }
    $target = if ($AppBundle) { 'appbundle' } else { 'apk' }
    $modeArgument = if ($Mode -eq 'Release') { '--release' } else { '--debug' }
    & flutter build $target $modeArgument
    if ($LASTEXITCODE -ne 0) { throw 'Android 构建失败。' }
  }
  finally {
    Pop-Location
  }
}

function Install-WorkshopDebugApk {
  $apk = Join-Path $WorkspaceRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path $apk)) {
    throw '尚未找到 debug APK，请先运行 Build-WorkshopAndroid。'
  }
  $adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
  & $adb devices
  & $adb install -r $apk
  if ($LASTEXITCODE -ne 0) { throw '安装失败，请确认手机已开启 USB 调试并授权此电脑。' }
}
