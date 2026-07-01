$file = "C:\Users\gnw28\Desktop\APPSOURSE\avplayer-online-video-master\entry\src\main\ets\view\BasicVideoPlayer.ets"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

# 1. Remove CaptionFontComponent import
$content = $content.Replace("import { CaptionFontComponent } from '../components/CaptionFontComponent';`r`n", "")

# 2. Rename AiCaptionConfigDialog to UnifiedCaptionDialog in the builder definition
$content = $content.Replace("  AiCaptionConfigDialog() {", "  UnifiedCaptionDialog() {")

# 3. Replace the old CaptionFontComponent usage block with simple UnifiedCaptionDialog call
$oldText = "if (this.isShowCaptionConfig) {`r`n        CaptionFontComponent({"
$newText = "if (this.isShowCaptionConfig) {`r`n        this.UnifiedCaptionDialog()"
$content = $content.Replace($oldText, $newText)

# 4. Remove the separate AiCaptionConfigDialog call
$content = $content.Replace("if (this.isAiCaptionConfigShown) {`r`n        this.UnifiedCaptionDialog()`r`n      }`r`n", "")

# 5. Clean up leftover CaptionFontComponent closing
# Find and remove the CaptionFontComponent block body
$idx = $content.IndexOf("if (this.isShowCaptionConfig)")
if ($idx -ge 0) {
    $endMarker = "this.UnifiedCaptionDialog()`r`n"
    $endIdx = $content.IndexOf($endMarker, $idx)
    if ($endIdx -ge 0) {
        $searchFrom = $endIdx + $endMarker.Length
        # Find the closing } of the old CaptionFontComponent block
        # We need to skip past the old CaptionFontComponent parameters until we find the ) and }
        $braceCount = 0
        $i = $searchFrom
        $found = $false
        while ($i -lt $content.Length -and !$found) {
            $ch = $content[$i]
            if ($ch -eq '(') { $braceCount++ }
            elseif ($ch -eq ')') { 
                if ($braceCount -eq 0) {
                    # Found the closing paren of CaptionFontComponent
                    $j = $i + 1
                    # Skip whitespace and find the next }
                    while ($j -lt $content.Length) {
                        $nc = $content[$j]
                        if ($nc -eq '}') {
                            # This is the closing } of the if block
                            # But there might be multiple } - keep the one before our next meaningful code
                            $k = $j + 1
                            while ($k -lt $content.Length -and ($content[$k] -eq " " -or $content[$k] -eq "`r" -or $content[$k] -eq "`n")) { $k++ }
                            if ($k -lt $content.Length) {
                                # Remove from here to j inclusive
                                $content = $content.Substring(0, $searchFrom) + $content.Substring($k)
                                $found = $true
                                break
                            }
                            $j++
                        } else { $j++ }
                    }
                    if (!$found) { break }
                }
                else { $braceCount-- }
            }
            $i++
        }
    }
}

[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
Write-Host "OK"
