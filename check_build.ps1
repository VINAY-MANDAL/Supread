$JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:JAVA_HOME = $JAVA_HOME

Set-Location E:\pdf_reader_flutter

# Check if outputs exists
$outputPath = "E:\pdf_reader_flutter\build\app\outputs\apk\release"
if (Test-Path $outputPath) {
    Write-Host "Output folder exists!"
    Get-ChildItem $outputPath -Filter "*.apk"
} else {
    Write-Host "Output folder does not exist. Starting build..."
    cmd /c flutter build apk --release
    
    if (Test-Path $outputPath) {
        Write-Host "Build successful! APK files:"
        Get-ChildItem $outputPath -Filter "*.apk"
    } else {
        Write-Host "Build completed but output folder still doesn't exist."
    }
}
